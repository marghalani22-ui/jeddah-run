import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/location.dart';
import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/jmap.dart';
import 'summary_screen.dart';

/// Live run: GPS-tracked distance, time and pace with the route drawn on the map.
class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  // Readings worse than this are ignored; jumps faster than this are GPS noise.
  static const _maxAccuracy = 25.0, _maxSpeed = 8.0, _minStep = 2.0;

  final _sw = Stopwatch();
  final _pts = <LatLng>[];
  final DateTime _startedAt = DateTime.now();
  StreamSubscription<Position>? _sub;
  Timer? _tick;
  Position? _last;
  double _meters = 0, _accuracy = 999;
  bool _paused = false, _drawing = false;
  MapLibreMapController? _map;
  Line? _line;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sw.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _sub = Geolocator.getPositionStream(locationSettings: runSettings()).listen(_onPos);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _onPos(Position p) {
    _accuracy = p.accuracy;
    if (_paused || p.accuracy > _maxAccuracy) {
      if (mounted) setState(() {});
      return;
    }
    final here = LatLng(p.latitude, p.longitude);
    final last = _last;
    if (last != null) {
      final d = Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude);
      final dt = p.timestamp.difference(last.timestamp).inMilliseconds / 1000;
      if (d < _minStep) return;
      if (dt > 0 && d / dt > _maxSpeed) return;
      _meters += d;
    }
    _last = p;
    _pts.add(here);
    _draw();
    _map?.animateCamera(CameraUpdate.newLatLng(here));
    if (mounted) setState(() {});
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
      _paused = !_paused;
      if (_paused) {
        _sw.stop();
      } else {
        _sw.start();
        _last = null; // don't bridge the gap walked while paused
      }
    });
  }

  Future<void> _finish() async {
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
    await _sub?.cancel();
    if (_meters < 50) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final run = Run(
      start: _startedAt,
      secs: _sw.elapsed.inSeconds,
      meters: _meters,
      path: _pts.map((e) => [e.latitude, e.longitude]).toList(),
    );
    await runStore.add(run);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SummaryScreen(run: run, fresh: true)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final secs = _sw.elapsed.inSeconds;
    final km = _meters / 1000;
    final gps = _accuracy <= 10 ? ('ممتاز', p.good) : _accuracy <= _maxAccuracy ? ('مقبول', p.goldInk) : ('يبحث…', p.bad);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: JMap(
                  myLocation: true,
                  follow: true,
                  zoom: 16.5,
                  onCreated: (c) => _map = c,
                  onStyleLoaded: _draw,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.l),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: p.card.withValues(alpha: .94), borderRadius: BorderRadius.circular(Radii.chip)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.gps_fixed, size: 16, color: gps.$2),
                      const SizedBox(width: 6),
                      Text('GPS ${gps.$1}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: gps.$2)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
              boxShadow: const [BoxShadow(color: Color(0x2214213D), blurRadius: 20, offset: Offset(0, -4))],
            ),
            padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, Gap.l, Gap.l),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(fmtKm(km), style: TextStyle(fontSize: 64, fontWeight: FontWeight.w700, height: 1, color: p.ink)),
                Text('كيلومتر', style: TextStyle(color: p.muted, fontSize: 13)),
                const SizedBox(height: Gap.l),
                Row(children: [
                  _Stat(value: fmtDur(secs), label: 'الزمن'),
                  _Stat(value: fmtPace(km > 0.05 ? secs / km : 0), label: 'السرعة /كم'),
                  _Stat(value: '${(km * pointsPerKm).floor()}', label: 'نقاط'),
                ]),
                const SizedBox(height: Gap.xl),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _RoundBtn(
                    icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    label: _paused ? 'كمّل' : 'إيقاف مؤقت',
                    color: _paused ? Brand.leaf : Brand.navy,
                    onTap: _togglePause,
                  ),
                  const SizedBox(width: Gap.xxl),
                  _RoundBtn(icon: Icons.stop_rounded, label: 'إنهاء', color: Brand.coral, onTap: _finish),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.pal.ink)),
          Text(label, style: TextStyle(fontSize: 12, color: context.pal.muted)),
        ]),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 76, height: 76, child: Icon(icon, color: Colors.white, size: 38)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.pal.muted)),
      ]);
}
