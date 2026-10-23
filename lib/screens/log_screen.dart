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
      const _DailyCard(),
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

/// Daily average: a bar per day with the average as a dashed line.
class _DailyCard extends StatefulWidget {
  const _DailyCard();

  @override
  State<_DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<_DailyCard> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final today = DateUtils.dateOnly(DateTime.now());
    // Oldest first.
    final days = [for (var i = _days - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    final valid = runStore.runs.where((r) => r.flag == null).toList();
    final km = [
      for (final d in days) valid.where((r) => DateUtils.isSameDay(r.start, d)).fold(0.0, (a, r) => a + r.km),
    ];
    final secs = valid.where((r) => !r.start.isBefore(days.first)).fold(0, (a, r) => a + r.secs);
    final total = km.fold(0.0, (a, b) => a + b);
    final active = km.where((k) => k > 0).length;
    final avg = total / _days;
    final avgActive = active == 0 ? 0.0 : total / active;
    final best = km.reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('متوسط الجري اليومي', style: Theme.of(context).textTheme.titleMedium)),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              segments: const [ButtonSegment(value: 7, label: Text('أسبوع')), ButtonSegment(value: 30, label: Text('شهر'))],
              selected: {_days},
              onSelectionChanged: (v) => setState(() => _days = v.first),
            ),
          ]),
          const SizedBox(height: Gap.s),
          Text.rich(TextSpan(children: [
            TextSpan(text: fmtKm(avg), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: p.ink, height: 1.1)),
            TextSpan(text: ' كم باليوم', style: TextStyle(fontSize: 14, color: p.muted)),
          ])),
          Text('آخر ${_days == 7 ? '7 أيام' : '30 يوم'} · المجموع ${fmtKm(total)} كم', style: TextStyle(fontSize: 12.5, color: p.muted)),
          const SizedBox(height: Gap.m),
          SizedBox(height: 130, child: CustomPaint(size: Size.infinite, painter: _DailyBars(km, avg, days, p, DefaultTextStyle.of(context).style.fontFamily))),
          const SizedBox(height: Gap.xs),
          Row(children: [
            Container(width: 16, height: 2, color: p.ink.withValues(alpha: .55)),
            const SizedBox(width: 6),
            Text('المتوسط ${fmtKm(avg)} كم', style: TextStyle(fontSize: 11.5, color: p.muted)),
            const SizedBox(width: Gap.m),
            Container(width: 10, height: 10, decoration: BoxDecoration(gradient: Grad.sunset, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text('فوق المتوسط', style: TextStyle(fontSize: 11.5, color: p.muted)),
          ]),
          const SizedBox(height: Gap.m),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _MiniStat(value: '$active/$_days', label: 'أيام جريت'),
            _MiniStat(value: fmtKm(avgActive), label: 'يوم الجري'),
            _MiniStat(value: fmtPace(total > 0 ? secs / total : 0), label: 'السرعة'),
            _MiniStat(value: fmtKm(best), label: 'أفضل يوم'),
          ]),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: context.pal.ink)),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: context.pal.muted)),
        ]),
      );
}

class _DailyBars extends CustomPainter {
  _DailyBars(this.v, this.avg, this.days, this.p, this.font);
  final List<double> v;
  final double avg;
  final List<DateTime> days;
  final Palette p;
  final String? font;

  static const _names = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']; // Mon..Sun

  @override
  void paint(Canvas c, Size s) {
    final n = v.length, labels = n <= 7;
    final bottom = labels ? 18.0 : 4.0, top = 16.0;
    final h = s.height - top - bottom;
    final mx = math.max(v.reduce(math.max), math.max(avg * 1.4, 1.0));
    final gap = n <= 7 ? 12.0 : 3.0;
    final bw = (s.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      // RTL: today on the left end.
      final x = s.width - (i + 1) * bw - i * gap;
      final bh = v[i] <= 0 ? 3.0 : math.max(5.0, v[i] / mx * h);
      final rect = Rect.fromLTWH(x, top + h - bh, bw, bh);
      final paint = Paint();
      if (v[i] <= 0) {
        paint.color = p.edge;
      } else if (v[i] >= avg) {
        paint.shader = Grad.sunset.createShader(rect);
      } else {
        paint.color = Brand.sea.withValues(alpha: .55);
      }
      c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(n <= 7 ? 7 : 3)), paint);
      if (labels) {
        final today = i == n - 1;
        _text(c, today ? 'اليوم' : _names[days[i].weekday - 1], Offset(x + bw / 2, s.height - 14), today ? Brand.coral : p.muted, 10.5);
        if (v[i] > 0) _text(c, v[i].toStringAsFixed(1), Offset(x + bw / 2, top + h - bh - 14), p.ink, 10);
      }
    }
    // Average line.
    final ay = top + h - avg / mx * h;
    final dash = Paint()
      ..color = p.ink.withValues(alpha: .55)
      ..strokeWidth = 1.2;
    for (double x = 0; x < s.width; x += 8) {
      c.drawLine(Offset(x, ay), Offset(math.min(x + 4, s.width), ay), dash);
    }
  }

  void _text(Canvas c, String t, Offset at, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: font, fontSize: size, fontWeight: FontWeight.w600, color: color)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(_DailyBars o) => true;
}
