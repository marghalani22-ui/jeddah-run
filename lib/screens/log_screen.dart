import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/runs.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'heatmap_screen.dart';
import 'summary_screen.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([runStore, settings]),
        builder: (context, _) => runStore.runs.isEmpty
            ? const PageBody(title: 'سجلّي', children: [
                EmptyState(
                  icon: Icons.directions_run,
                  title: 'ما فيه جولات للحين',
                  hint: 'ابدأ أول جولة من تبويب الخريطة، وتنحفظ هنا بمسارها وأرقامها.',
                ),
              ])
            : _Log(),
      );
}

class _Log extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final week = runStore.thisWeek.toList();
    final wkKm = runStore.weekKm, goal = settings.goalKm;
    final wkSecs = week.fold(0, (a, r) => a + r.secs);
    final weeks = runStore.lastWeeks(8);

    return PageBody(title: 'سجلّي', children: [
      Container(
        padding: const EdgeInsets.all(Gap.l + 2),
        decoration: BoxDecoration(gradient: Grad.sunset, borderRadius: BorderRadius.circular(26)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('هذا الأسبوع', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, fontWeight: FontWeight.w500)),
          Text.rich(TextSpan(children: [
            TextSpan(text: fmtKm(wkKm), style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1)),
            const TextSpan(text: ' كم', style: TextStyle(fontSize: 16, color: Color(0xE6FFFFFF))),
          ])),
          const SizedBox(height: Gap.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: (wkKm / goal).clamp(0, 1).toDouble(), minHeight: 8, color: Colors.white, backgroundColor: const Color(0x40FFFFFF)),
          ),
          const SizedBox(height: 6),
          Text(
            wkKm >= goal ? 'حققت هدفك ($goal كم) 🎉' : 'باقي ${fmtKm(goal - wkKm)} كم على هدفك ($goal كم)',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Gap.l),
          Row(children: [
            _HeroStat(value: '${week.length}', label: 'جولات'),
            _HeroStat(value: fmtDur(wkSecs), label: 'الزمن'),
            _HeroStat(value: fmtPace(wkKm > 0 ? wkSecs / wkKm : 0), label: 'لكل كم'),
          ]),
        ]),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHead('آخر 8 أسابيع', trailing: 'كم'),
            SizedBox(height: 140, child: CustomPaint(size: Size.infinite, painter: _Bars(weeks, goal.toDouble(), p))),
          ]),
        ),
      ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: Grad.night, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.local_fire_department_rounded, color: Brand.coral),
          ),
          title: const Text('خريطة مساراتي', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('كل جولاتك على خريطة وحدة، وشوارعك المفضلة تولّع', style: TextStyle(color: p.muted, fontSize: 12.5)),
          trailing: Icon(Icons.chevron_left_rounded, color: p.muted),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HeatmapScreen())),
        ),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead('الجولات', trailing: '${runStore.runs.length}'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < runStore.runs.length; i++) ...[
              if (i > 0) const Divider(indent: 16, endIndent: 16),
              _RunTile(run: runStore.runs[i]),
            ],
          ]),
        ),
      ]),
    ]);
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});
  final Run run;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, r = run;
    return ListTile(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SummaryScreen(run: r))),
                leading: CircleAvatar(backgroundColor: p.sand2, child: const Icon(Icons.route, color: Brand.coral, size: 20)),
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: Text(r.imported ? '${fmtWhen(r.start)} · ${r.source}' : fmtWhen(r.start), style: TextStyle(color: p.muted, fontSize: 12.5)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fmtKm(r.km)} كم', style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
                    Text('${fmtDur(r.secs)} · ${fmtPace(r.secPerKm)}', style: TextStyle(color: p.muted, fontSize: 12)),
                  ],
                ),
              );
  }
}

class _Bars extends CustomPainter {
  _Bars(this.v, this.goal, this.p);
  final List<double> v;
  final double goal;
  final Palette p;

  @override
  void paint(Canvas c, Size s) {
    final mx = math.max(v.reduce(math.max), goal);
    final n = v.length, gap = 10.0, top = 16.0;
    final bw = (s.width - gap * (n - 1)) / n, h = s.height - top;
    // RTL: this week sits on the left end, the oldest on the right.
    for (var i = 0; i < n; i++) {
      final x = s.width - (i + 1) * bw - i * gap;
      final bh = math.max(3.0, v[i] / mx * h);
      final last = i == n - 1;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, top + h - bh, bw, bh), const Radius.circular(5)),
        Paint()..color = last ? Brand.coral : Brand.sea.withValues(alpha: v[i] > 0 ? .5 : .15),
      );
      if (v[i] > 0 && (last || v[i] == v.reduce(math.max))) {
        final tp = TextPainter(
          text: TextSpan(text: v[i].toStringAsFixed(1), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.ink)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(x + bw / 2 - tp.width / 2, top + h - bh - 14));
      }
    }
    final gy = top + h - goal / mx * h;
    final dash = Paint()
      ..color = Brand.coral.withValues(alpha: .6)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 7) {
      c.drawLine(Offset(x, gy), Offset(math.min(x + 3, s.width), gy), dash);
    }
  }

  @override
  bool shouldRepaint(_Bars o) => true;
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12)),
        ]),
      );
}
