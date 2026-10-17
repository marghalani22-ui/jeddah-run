import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/jmap.dart';

/// Run summary: route on the real map, the numbers, and points earned.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.run, this.fresh = false});
  final Run run;
  final bool fresh;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  MapLibreMapController? _map;
  late final List<LatLng> _pts = widget.run.path.map((e) => LatLng(e[0], e[1])).toList();

  Future<void> _drawRoute() async {
    final m = _map;
    if (m == null || _pts.length < 2) return;
    await m.addLine(LineOptions(geometry: _pts, lineColor: '#F25C2C', lineWidth: 5, lineJoin: 'round'));
    await m.addCircle(CircleOptions(geometry: _pts.first, circleRadius: 6, circleColor: '#2FB36C', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
    await m.addCircle(CircleOptions(geometry: _pts.last, circleRadius: 6, circleColor: '#F25C2C', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
    await m.moveCamera(CameraUpdate.newLatLngBounds(boundsOf(_pts), left: 40, top: 60, right: 40, bottom: 40));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تحذف الجولة؟'),
        content: const Text('بتنحذف من سجلّك ونقاطها بتنخصم.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('احذف', style: TextStyle(color: Brand.coral))),
        ],
      ),
    );
    if (ok != true) return;
    await runStore.remove(widget.run);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.run, p = context.pal;
    return Scaffold(
      appBar: AppBar(
        title: Text(runTitle(r.start)),
        actions: [if (!widget.fresh) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'حذف')],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xxl), children: [
        Text(fmtWhen(r.start), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gap.m),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card),
          child: SizedBox(
            height: 260,
            child: _pts.length < 2
                ? ColoredBox(color: p.sand2, child: const Center(child: Text('ما فيه مسار محفوظ')))
                : JMap(
                    target: _pts.first,
                    zoom: 15,
                    interactive: false,
                    onCreated: (c) => _map = c,
                    onStyleLoaded: _drawRoute,
                  ),
          ),
        ),
        const SizedBox(height: Gap.l),
        KpiCard(children: [
          Kpi(value: fmtKm(r.km), unit: 'كم', label: 'المسافة', big: true),
          Kpi(value: fmtDur(r.secs), label: 'الزمن', big: true),
        ]),
        const SizedBox(height: Gap.m),
        KpiCard(children: [
          Kpi(value: fmtPace(r.secPerKm), unit: '/كم', label: 'متوسط السرعة'),
          Kpi(value: '+${r.points}', label: 'نقاط'),
        ]),
        if (widget.fresh) ...[
          const SizedBox(height: Gap.xl),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
        ],
      ]),
    );
  }
}
