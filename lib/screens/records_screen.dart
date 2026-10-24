import 'package:flutter/material.dart';

import '../state/records.dart';
import '../state/runs.dart';
import '../theme/tokens.dart';
import 'summary_screen.dart';

/// "أرقامي القياسية": speed records on top, distance and consistency below.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  static const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: runStore,
        builder: (context, _) {
          final recs = computeRecords(runStore.runs);
          final got = recs.length;
          Widget group(String id, String title) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, Gap.l, 4, Gap.s),
                  child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: context.pal.muted)),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final (i, d) in recordDefs.where((d) => d.group == id).indexed) ...[
                      if (i > 0) Divider(height: 1, indent: 64, color: context.pal.edge),
                      _RecordRow(def: d, rec: recs[d.id]),
                    ],
                  ]),
                ),
              ]);
          return Scaffold(
            appBar: AppBar(title: const Text('أرقامي القياسية')),
            body: ListView(padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xxl), children: [
              Container(
                padding: const EdgeInsets.all(Gap.l),
                decoration: BoxDecoration(gradient: Grad.night, borderRadius: BorderRadius.circular(Radii.card)),
                child: Row(children: [
                  ShaderMask(
                    shaderCallback: (r) => Grad.sunset.createShader(r),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 44),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$got من ${recordDefs.length} أرقام مسجّلة',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 2),
                      const Text('أرقام السرعة من الكيلوهات الكاملة في جولات لفّة',
                          style: TextStyle(color: Color(0xFFA9B3C7), fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ),
              group('speed', 'السرعة'),
              group('distance', 'المسافة والالتزام'),
            ]),
          );
        },
      );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.def, required this.rec});
  final RecordDef def;
  final Record? rec;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, r = rec;
    final on = r != null;
    return InkWell(
      onTap: r?.run == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(run: r!.run!))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: on ? Grad.sunset : null,
              color: on ? null : p.sand2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(def.icon, color: on ? Colors.white : p.muted, size: 21),
          ),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.ink)),
              Text(on ? (r.at == null ? '' : RecordsScreen.date(r.at!)) : def.hint, style: TextStyle(fontSize: 12, color: p.muted)),
            ]),
          ),
          Text(on ? r.display : '—', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: on ? p.ink : p.muted)),
          if (r?.run != null) Icon(Icons.chevron_left_rounded, color: p.muted, size: 20),
        ]),
      ),
    );
  }
}
