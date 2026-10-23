import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../services/background.dart';
import '../services/location.dart';
import '../services/steps.dart';
import '../services/weather.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import '../state/game.dart';
import '../state/mood.dart';
import '../state/phase.dart';
import '../widgets/sky.dart';
import '../widgets/game_widgets.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';
import '../widgets/celebration.dart';
import '../widgets/jmap.dart';
import '../widgets/weather_widgets.dart';
import 'points_screen.dart';
import 'run_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _map;
  bool _loc = false;

  @override
  void initState() {
    super.initState();
    _init();
    steps.addListener(_onSteps);
  }

  @override
  void dispose() {
    steps.removeListener(_onSteps);
    super.dispose();
  }

  void _onSteps() {
    final r = steps.justEarned;
    if (r == null || !mounted) return;
    steps.justEarned = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) celebrate(context, icon: Icons.directions_walk_rounded, title: 'مهمة الخطوات تمّت!', subtitle: '${fmtSteps(steps.today)} خطوة · +${r.points} نقطة', color: Brand.leaf);
    });
  }

  Future<void> _init() async {
    final ok = await hasLocation() || (mounted && await ensureLocation(context));
    if (!mounted) return;
    setState(() => _loc = ok);
    if (ok) _recenter();
    weather.refresh(force: ok);
  }

  Future<void> _recenter() async {
    if (!_loc) {
      final ok = await ensureLocation(context);
      if (!mounted || !ok) return;
      setState(() => _loc = true);
    }
    final p = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 16));
  }

  Future<void> _start() async {
    if (!await ensureLocation(context) || !mounted) return;
    if (!await heatCheck(context) || !mounted) return;
    await ensureBackgroundOk(context);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RunScreen(), fullscreenDialog: true));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(child: JMap(onCreated: (c) => _map = c, myLocation: _loc)),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: ListenableBuilder(
          listenable: phaseClock,
          builder: (context, _) => SkyBand(phase: phaseClock.phase, height: MediaQuery.of(context).padding.top + 190),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, 0),
            child: ListenableBuilder(
              listenable: Listenable.merge([runStore, settings, game]),
              builder: (context, _) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Header(),
                SizedBox(height: Gap.s),
                Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [ChallengesPill(), WeatherPill()]),
              ]),
            ),
          ),
        ),
      ),
      Positioned(
        left: Gap.m,
        right: Gap.m,
        bottom: Gap.m,
        child: ListenableBuilder(
          listenable: Listenable.merge([runStore, settings, steps, game]),
          builder: (context, _) => _WeekCard(onStart: _start, onRecenter: _recenter),
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (mood, line) = moodNow();
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Color(0x1F14213D), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Row(children: [
            Image.asset(moodAsset(mood), width: 44, height: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(greeting(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.ink)),
                Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.muted)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(width: Gap.s),
      GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PointsScreen())),
        child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(gradient: Grad.night, borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.toll, color: Brand.sun, size: 20),
          const SizedBox(width: 6),
          Text('${game.balance}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
      ),
      ),
    ]);
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.onStart, required this.onRecenter});
  final VoidCallback onStart, onRecenter;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final goal = settings.goalKm.toDouble(), wk = runStore.weekKm;
    final left = goal - wk;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: Gap.s),
        child: Material(
          color: p.card,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: const Color(0x3314213D),
          child: IconButton(onPressed: onRecenter, icon: Icon(Icons.my_location, color: p.ink), tooltip: 'موقعي'),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(Gap.l),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x2914213D), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Ring(
              value: goal == 0 ? 0 : wk / goal,
              size: 76,
              stroke: 9,
              child: Text('${(goal == 0 ? 0 : (wk / goal * 100).clamp(0, 999)).round()}%',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: p.ink)),
            ),
            const SizedBox(width: Gap.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('هدف الأسبوع', style: TextStyle(fontSize: 12.5, color: p.muted)),
                Text.rich(TextSpan(children: [
                  TextSpan(text: fmtKm(wk), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: p.ink, height: 1.1)),
                  TextSpan(text: '  من ${settings.goalKm} كم', style: TextStyle(fontSize: 14, color: p.muted)),
                ])),
                const SizedBox(height: 2),
                Text(
                  left <= 0 ? 'حققت هدفك! كل كيلو زيادة مكسب' : 'باقي ${fmtKm(left)} كم · تقدر عليها!',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.good),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: Gap.m),
          const _StepsRow(),
          const SizedBox(height: Gap.m),
          GradientButton(label: 'ابدأ جولة', icon: Icons.play_arrow_rounded, onPressed: onStart, height: 58),
        ]),
      ),
    ]);
  }
}

/// Daily step mission inside the week card.
class _StepsRow extends StatelessWidget {
  const _StepsRow();

  Future<void> _pickGoal(BuildContext context) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('هدف الخطوات اليومي', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('توصل له وتاخذ النقاط مرة كل يوم. الهدف الأعلى نقاطه أكثر.', style: TextStyle(color: c.pal.muted)),
              const SizedBox(height: Gap.m),
              for (final e in Game.stepGoals.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(settings.stepGoal == e.key ? Icons.radio_button_checked : Icons.radio_button_off, color: Brand.coral),
                  title: Text('${fmtSteps(e.key)} خطوة', style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text('+${e.value} نقطة', style: const TextStyle(color: Brand.coral, fontWeight: FontWeight.w700)),
                  onTap: () {
                    steps.setGoal(e.key);
                    Navigator.pop(c);
                  },
                ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pts = Game.stepGoals[steps.goal] ?? 20;
    if (!steps.on) {
      if (steps.ready && !steps.available) return const SizedBox.shrink();
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: steps.enable,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: p.goodSoft, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(Icons.directions_walk_rounded, color: p.good),
            const SizedBox(width: Gap.s),
            Expanded(child: Text('فعّل عداد الخطوات · مهمة يومية بـ +$pts نقطة', style: TextStyle(color: p.good, fontWeight: FontWeight.w700, fontSize: 13))),
            Icon(Icons.chevron_left_rounded, color: p.good),
          ]),
        ),
      );
    }
    final n = steps.today, goal = steps.goal;
    final done = game.stepsDone(DateTime.now());
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _pickGoal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: p.sand2, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(Icons.directions_walk_rounded, color: done ? p.good : Brand.coral),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(fmtSteps(n), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.ink)),
                Text(' / ${fmtSteps(goal)} خطوة', style: TextStyle(fontSize: 12.5, color: p.muted)),
                const Spacer(),
                Text(done ? '✓ +$pts' : '+$pts نقطة',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: done ? p.good : Brand.coral)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal == 0 ? 0 : (n / goal).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  color: done ? p.good : Brand.coral,
                  backgroundColor: p.edge,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
