import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/jmap.dart';

/// Every recorded route on one map. Lines are translucent, so streets you
/// run often glow brighter: a personal heatmap.
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  MapLibreMapController? _map;
  int _days = 0; // 0 = all time

  List<Run> get _runs => runStore.runs
      .where((r) => r.path.length > 1 && (_days == 0 || DateTime.now().difference(r.start).inDays < _days))
      .toList();

  Future<void> _draw() async {
    final m = _map;
    if (m == null) return;
    await m.clearLines();
    final runs = _runs;
    if (runs.isEmpty) return;
    final all = <LatLng>[];
    final lines = <LineOptions>[];
    for (final r in runs) {
      // Thin the path a little; the shape survives and the map stays light.
      final step = (r.path.length / 400).ceil().clamp(1, 50);
      final pts = [for (var i = 0; i < r.path.length; i += step) LatLng(r.path[i][0], r.path[i][1])];
      all.addAll(pts);
      lines.add(LineOptions(geometry: pts, lineColor: '#F25C2C', lineWidth: 4, lineOpacity: .28, lineBlur: 1.5, lineJoin: 'round'));
    }
    await m.addLines(lines);
    await m.moveCamera(CameraUpdate.newLatLngBounds(boundsOf(all), left: 40, top: 140, right: 40, bottom: 120));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final runs = _runs;
    final km = runs.fold(0.0, (a, r) => a + r.km);
    final first = runs.isNotEmpty ? runs.first.path.first : const [21.54, 39.17];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('خريطة مساراتي'),
        backgroundColor: p.card.withValues(alpha: .85),
      ),
      body: Stack(fit: StackFit.expand, children: [
        JMap(
          target: LatLng(first[0], first[1]),
          zoom: 13,
          onCreated: (c) => _map = c,
          onStyleLoaded: _draw,
        ),
        Positioned(
          left: Gap.l,
          right: Gap.l,
          bottom: Gap.l + MediaQuery.of(context).padding.bottom,
          child: Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(Radii.card),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(width: 26, height: 6, decoration: BoxDecoration(gradient: Grad.sunset, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: Text('${runs.length} جولة · ${fmtKm(km)} كم · كل ما كان الخط أقوى جريت فيه أكثر',
                      style: TextStyle(fontSize: 12.5, color: p.muted)),
                ),
              ]),
              const SizedBox(height: Gap.s),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 30, label: Text('شهر')),
                  ButtonSegment(value: 90, label: Text('3 شهور')),
                  ButtonSegment(value: 365, label: Text('سنة')),
                  ButtonSegment(value: 0, label: Text('الكل')),
                ],
                selected: {_days},
                onSelectionChanged: (s) {
                  setState(() => _days = s.first);
                  _draw();
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
