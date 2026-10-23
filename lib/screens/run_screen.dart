import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/location.dart';
import '../services/reminders.dart';
import '../services/run_draft.dart';
import '../services/voice.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/jmap.dart';
import 'summary_screen.dart';

/// Live run: countdown, GPS-tracked distance/time/pace, auto-pause,
/// per-km splits with spoken cues, and the route drawn on the map.
class RunScreen extends StatefulWidget {
  const RunScreen({super.key, this.resume});

  /// Continue a run that was interrupted (app closed or killed).
  final RunDraft? resume;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

enum _Phase { countdown, running, paused, autoPaused }

class _RunScreenState extends State<RunScreen> with WidgetsBindingObserver {
  // Readings worse than this are ignored; jumps faster than this are GPS noise or a vehicle.
  static const _maxAccuracy = 25.0, _maxSpeed = 8.0, _minStep = 2.0;
  // Auto-pause after this long without movement; resume above this speed.
  static const _stillFor = Duration(seconds: 8), _resumeSpeed = 1.2;

  final _sw = Stopwatch();
  final _pts = <LatLng>[];
  final _splits = <int>[];
  final _voice = Voice();
  late final DateTime _startedAt;
  StreamSubscription<Position>? _sub;
  Timer? _tick;
  Position? _last;
  DateTime _lastMove = DateTime.now();
  double _meters = 0, _accuracy = 999;
  int _count = 3, _accepted = 0, _rejected = 0, _splitAt = 0;
  _Phase _phase = _Phase.countdown;
  bool _drawing = false;
  MapLibreMapController? _map;
  Line? _line;

  bool get _moving => _phase == _Phase.running;

  // Time from an interrupted run that this screen continues.
  int _baseSecs = 0, _sinceSave = 0;
  int get _elapsed => _baseSecs + _sw.elapsed.inSeconds;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _voice.init();
    WidgetsBinding.instance.addObserver(this);
    reminders.onRunAction = (a) {
      if (!mounted || _phase == _Phase.countdown) return;
      if (a == 'run_pause') _togglePause();
      if (a == 'run_stop') _finish();
    };
    final d = widget.resume;
    if (d != null) {
      _startedAt = d.start;
      _baseSecs = d.secs;
      _meters = d.meters;
      _pts.addAll(d.path.map((e) => LatLng(e[0], e[1])));
      _splits.addAll(d.splits);
      _splitAt = d.splitAt;
      _accepted = d.accepted;
      _rejected = d.rejected;
      _lastMove = DateTime.now();
      _phase = _Phase.running;
      _sw.start();
      // _last stays null so the gap since the app closed isn't bridged with a straight line.
      WidgetsBinding.instance.addPostFrameCallback((_) => _voice.say('كمّلنا جولتك'));
    }
    // GPS warms up during the countdown.
    _sub = Geolocator.getPositionStream(locationSettings: runSettings()).listen(_onPos);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reminders.onRunAction = null;
    _closed = true;
    reminders.cancelRun();
    _sub?.cancel();
    _tick?.cancel();
    _voice.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  // Leaving the app is the moment it is most likely to be killed: save now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive || s == AppLifecycleState.detached) _saveDraft();
  }

  Future<void> _saveDraft() async {
    if (_phase == _Phase.countdown || _closed) return;
    _sinceSave = 0;
    await RunDraft(
      start: _startedAt,
      secs: _elapsed,
      meters: _meters,
      path: _pts.map((e) => [e.latitude, e.longitude]).toList(),
      splits: List.of(_splits),
      splitAt: _splitAt,
      accepted: _accepted,
      rejected: _rejected,
      savedAt: DateTime.now(),
    ).save();
  }

  bool _closed = false;
  int _ticks = 0;

  void _notify() {
    final km = _meters / 1000, secs = _elapsed;
    final paused = _phase == _Phase.paused || _phase == _Phase.autoPaused;
    reminders.showRun(
      title: '${paused ? '⏸' : '🏃'} ${fmtKm(km)} كم · ${fmtDur(secs)}',
      body: paused
          ? (_phase == _Phase.paused ? 'متوقف مؤقتاً' : 'إيقاف تلقائي · تحرّك وتكمّل')
          : 'السرعة ${fmtPace(km > 0.05 ? secs / km : 0)} /كم · +${kmPoints(km)} نقطة',
      paused: _phase == _Phase.paused,
    );
  }

  void _onTick() {
    if (_phase != _Phase.countdown && ++_sinceSave >= 10) _saveDraft();
    if (_phase != _Phase.countdown && !_closed && ++_ticks % 3 == 0) _notify();
    if (!mounted) return;
    if (_phase == _Phase.countdown) {
      HapticFeedback.heavyImpact();
      if (_count > 1) {
        setState(() => _count--);
      } else {
        _startedAt = DateTime.now();
        _lastMove = _startedAt;
        _sw.start();
        _voice.say('يلا بدأنا');
        setState(() => _phase = _Phase.running);
      }
      return;
    }
    if (_moving && settings.autoPause && DateTime.now().difference(_lastMove) > _stillFor) {
      _sw.stop();
      _phase = _Phase.autoPaused;
      HapticFeedback.mediumImpact();
    }
    setState(() {});
  }

  void _onPos(Position p) {
    _accuracy = p.accuracy;
    if (!mounted) return;
    if (_phase == _Phase.countdown || _phase == _Phase.paused || p.accuracy > _maxAccuracy) {
      setState(() {});
      return;
    }

    // Wake from auto-pause once the runner is clearly moving again.
    // Some phones report speed as 0, so moving 10 m away also counts.
    if (_phase == _Phase.autoPaused) {
      final l = _last;
      final away = l == null ? 99.0 : Geolocator.distanceBetween(l.latitude, l.longitude, p.latitude, p.longitude);
      if (p.speed < _resumeSpeed && away < 10) return;
      _phase = _Phase.running;
      _sw.start();
      HapticFeedback.mediumImpact();
    }

    final here = LatLng(p.latitude, p.longitude);
    final last = _last;
    if (last != null) {
      final d = Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude);
      final dt = p.timestamp.difference(last.timestamp).inMilliseconds / 1000;
      if (d < _minStep) return;
      if (dt > 0 && d / dt > _maxSpeed) {
        _rejected++;
        return;
      }
      _accepted++;
      _meters += d;
      _lastMove = DateTime.now();
      _checkSplit();
    } else {
      _lastMove = DateTime.now();
    }
    _last = p;
    _pts.add(here);
    _draw();
    _map?.animateCamera(CameraUpdate.newLatLng(here));
    setState(() {});
  }

  void _checkSplit() {
    final km = (_meters / 1000).floor();
    if (km <= _splits.length) return;
    final now = _elapsed;
    final split = now - _splitAt;
    _splitAt = now;
    _splits.add(split);
    HapticFeedback.heavyImpact();
    _voice.say('كيلو $km. الزمن ${spokenDur(now)}. سرعة الكيلو ${spokenDur(split)}');
  }

  Future<void> _draw() async {
    final m = _map;
    if (m == null || _pts.length < 2 || _drawing) return;
    _drawing = true;
    try {
      final opts = LineOptions(geometry: List.of(_pts), lineColor: '#F25C2C', lineWidth: 6, lineJoin: 'round');
      if (_line == null) {
        _line = await m.addLine(opts);
      } else {
        await m.updateLine(_line!, opts);
      }
    } finally {
      _drawing = false;
    }
  }

  void _togglePause() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_phase == _Phase.paused) {
        _phase = _Phase.running;
        _sw.start();
        _last = null; // don't bridge the gap walked while paused
        _lastMove = DateTime.now();
        _voice.say('كمّلنا');
      } else {
        _phase = _Phase.paused;
        _sw.stop();
        _voice.say('توقف مؤقت');
      }
    });
    _notify();
  }

  Future<void> _finish() async {
    if (_phase == _Phase.countdown) {
      Navigator.pop(context);
      return;
    }
    _saveDraft();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تنهي الجولة؟'),
        content: Text(_meters < 50 ? 'المسافة أقل من 50 م، ما بتنحفظ.' : 'بنحفظ ${fmtKm(_meters / 1000)} كم في سجلّك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('كمّل')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('أنهِ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _sw.stop();
    _closed = true;
    await _sub?.cancel();
    reminders.cancelRun();
    if (_meters < 50) {
      await RunDraft.clear();
      if (mounted) Navigator.pop(context);
      return;
    }
    final secs = _elapsed;
    final run = Run(
      start: _startedAt,
      secs: secs,
      meters: _meters,
      path: _pts.map((e) => [e.latitude, e.longitude]).toList(),
      splits: List.of(_splits),
      flag: checkRun(meters: _meters, secs: secs, rejected: _rejected, accepted: _accepted),
    );
    final c = await commitRun(run);
    _voice.say('خلصت. ${fmtKm(run.km)} كيلو في ${spokenDur(secs)}');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SummaryScreen(run: run, fresh: true, rewards: c.rewards, levelUp: c.levelUp, goalReached: c.goalReached)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final secs = _elapsed;
    final km = _meters / 1000;
    final gps = _accuracy <= 10 ? ('ممتاز', p.good) : _accuracy <= _maxAccuracy ? ('مقبول', p.goldInk) : ('يبحث…', p.bad);
    final status = switch (_phase) {
      _Phase.paused => 'متوقف',
      _Phase.autoPaused => 'إيقاف تلقائي · تحرّك وتكمّل',
      _ => null,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: Stack(children: [
          Column(children: [
            Expanded(
              child: Stack(children: [
                Positioned.fill(
                  child: JMap(myLocation: true, follow: true, zoom: 16.5, onCreated: (c) => _map = c, onStyleLoaded: _draw),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.l),
                    child: Row(children: [
                      _Pill(icon: Icons.gps_fixed, text: 'GPS ${gps.$1}', color: gps.$2),
                      const Spacer(),
                      ListenableBuilder(
                        listenable: settings,
                        builder: (_, __) => IconButton.filledTonal(
                          onPressed: () => settings.setVoice(!settings.voice),
                          icon: Icon(settings.voice ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                          tooltip: settings.voice ? 'إيقاف الصوت' : 'تشغيل الصوت',
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: Grad.night,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.l),
              child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: status == null
                        ? const SizedBox(height: 26)
                        : Container(
                            key: ValueKey(status),
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: const Color(0x33FFB81C), borderRadius: BorderRadius.circular(Radii.chip)),
                            child: Text(status, style: const TextStyle(color: Color(0xFFFFD27A), fontWeight: FontWeight.w600, fontSize: 12.5)),
                          ),
                  ),
                  Text(fmtKm(km), style: const TextStyle(fontSize: 92, fontWeight: FontWeight.w700, height: 1.05, color: Colors.white, letterSpacing: -1)),
                  const Text('كيلومتر', style: TextStyle(color: Color(0xFFA3AEC6), fontSize: 14)),
                  const SizedBox(height: Gap.l),
                  Row(children: [
                    _Stat(value: fmtDur(secs), label: 'الزمن'),
                    _Stat(value: fmtPace(km > 0.05 ? secs / km : 0), label: 'لكل كم'),
                    _Stat(value: '+${kmPoints(km)}', label: 'نقطة', color: Brand.sun),
                  ]),
                  if (_splits.isNotEmpty) ...[
                    const SizedBox(height: Gap.m),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFF1E2D4F), borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        const Text('آخر كيلو', style: TextStyle(color: Color(0xFFA3AEC6), fontSize: 13.5)),
                        const Spacer(),
                        Text(fmtPace(_splits.last.toDouble()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        if (_splits.length > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            _splits.last <= _splits[_splits.length - 2]
                                ? 'أسرع بـ ${_splits[_splits.length - 2] - _splits.last} ث'
                                : 'أبطأ بـ ${_splits.last - _splits[_splits.length - 2]} ث',
                            style: TextStyle(
                              color: _splits.last <= _splits[_splits.length - 2] ? const Color(0xFF4ADE8B) : const Color(0xFFFF9A6B),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ],
                  const SizedBox(height: Gap.xl),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _RoundBtn(
                      icon: _phase == _Phase.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      label: _phase == _Phase.paused ? 'كمّل' : 'إيقاف مؤقت',
                      color: _phase == _Phase.paused ? Brand.leaf : Colors.white,
                      iconColor: _phase == _Phase.paused ? Colors.white : Brand.navy,
                      onTap: _phase == _Phase.countdown ? null : _togglePause,
                    ),
                    const SizedBox(width: Gap.xxl),
                    _RoundBtn(icon: Icons.stop_rounded, label: 'إنهاء', color: Brand.coral, onTap: _finish),
                  ]),
                ]),
              ),
            ),
          ]),
          if (_phase == _Phase.countdown)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xF20E1525),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Text('$_count',
                          key: ValueKey(_count),
                          style: const TextStyle(fontSize: 140, fontWeight: FontWeight.w700, color: Colors.white, height: 1)),
                    ),
                    const SizedBox(height: Gap.l),
                    Text('GPS ${gps.$1}', style: const TextStyle(color: Color(0xFFA9B3C7), fontSize: 14)),
                    const SizedBox(height: Gap.xl),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: context.pal.card.withValues(alpha: .94), borderRadius: BorderRadius.circular(Radii.chip)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color = Colors.white});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFFA3AEC6))),
        ]),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, required this.color, required this.onTap, this.iconColor = Colors.white});
  final Color iconColor;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(children: [
        Material(
          color: onTap == null ? color.withValues(alpha: .4) : color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 80, height: 80, child: Icon(icon, color: iconColor, size: 38)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFA3AEC6))),
      ]);
}
