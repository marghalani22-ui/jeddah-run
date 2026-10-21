import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/jmap.dart';
import '../widgets/gradient_button.dart';
import 'share_screen.dart';

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

  void _openShare() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShareScreen(run: widget.run)));

  Future<void> _rename() async {
    final ctl = TextEditingController(text: widget.run.name ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('اسم الجولة'),
        content: TextField(controller: ctl, autofocus: true, maxLength: 30, decoration: InputDecoration(hintText: runTitle(widget.run.start))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (v == null) return;
    await runStore.rename(widget.run, v);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.run, p = context.pal;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          IconButton(onPressed: _openShare, icon: const Icon(Icons.ios_share), tooltip: 'مشاركة'),
          IconButton(onPressed: _rename, icon: const Icon(Icons.edit_outlined), tooltip: 'تسمية الجولة'),
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'حذف'),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xxl), children: [
        Text(fmtWhen(r.start), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gap.m),
        if (r.flag != null) ...[
          Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(color: p.badSoft, borderRadius: BorderRadius.circular(Radii.btn)),
            child: Row(children: [
              Icon(Icons.info_outline, color: p.bad),
              const SizedBox(width: Gap.s),
              Expanded(child: Text('ما انحسبت نقاط لهذي الجولة: ${r.flag}', style: TextStyle(color: p.bad, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: Gap.m),
        ],
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
        if (r.splits.isNotEmpty) ...[
          const SizedBox(height: Gap.xl),
          const SectionHead('كل كيلو', trailing: 'الزمن'),
          _Splits(run: r),
        ],
        const SizedBox(height: Gap.xl),
        GradientButton(onPressed: _openShare, icon: Icons.ios_share, label: 'شارك جولتك'),
        if (widget.fresh) ...[
          const SizedBox(height: Gap.s),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ]),
    );
  }
}

/// One row per full kilometre, bar length relative to the slowest split.
class _Splits extends StatelessWidget {
  const _Splits({required this.run});
  final Run run;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, sp = run.splits;
    final slow = sp.reduce((a, b) => a > b ? a : b), fast = sp.reduce((a, b) => a < b ? a : b);
    final restM = run.meters - sp.length * 1000;
    final restS = run.secs - sp.fold(0, (a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(children: [
          for (var i = 0; i < sp.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600))),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: (sp[i] / slow).clamp(.15, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: sp[i] == fast ? Brand.coral : Brand.sea.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Gap.m),
                SizedBox(
                  width: 52,
                  child: Text(fmtPace(sp[i].toDouble()),
                      textAlign: TextAlign.end,
                      style: TextStyle(fontWeight: sp[i] == fast ? FontWeight.w700 : FontWeight.w500, color: p.ink)),
                ),
              ]),
            ),
          if (restM >= 50)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(child: Text('آخر ${restM.round()} م', style: TextStyle(color: p.muted, fontSize: 12.5))),
                Text(fmtPace(restS / (restM / 1000)), style: TextStyle(color: p.muted, fontSize: 12.5)),
              ]),
            ),
        ]),
      ),
    );
  }
}
