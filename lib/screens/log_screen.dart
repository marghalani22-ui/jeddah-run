import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  String tab = 'week';

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final w = Demo.weeks;
    final cur = w.last, prev = w[w.length - 2];
    final up = cur >= prev;
    final pct = ((cur - prev) / prev * 100).abs().round();

    return PageBody(children: [
      Text('سجلّي', style: Theme.of(context).textTheme.headlineMedium),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'week', label: Text('الأسبوع')),
          ButtonSegment(value: 'month', label: Text('الشهر')),
          ButtonSegment(value: 'year', label: Text('السنة')),
        ],
        selected: {tab},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => tab = s.first),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('هذا الأسبوع', style: Theme.of(context).textTheme.bodySmall),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '$cur', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' كم', style: TextStyle(fontSize: 14, color: p.muted)),
                  ])),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: up ? p.goodSoft : p.badSoft,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Text('${up ? '▲' : '▼'} $pct%',
                    style: TextStyle(color: up ? p.good : p.bad, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ]),
            const SizedBox(height: Gap.m),
            const Bar(value: Demo.weekKm / Demo.goalKm),
            const SizedBox(height: 6),
            Text('باقي ${(Demo.goalKm - cur).toStringAsFixed(1)} كم على هدفك',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Gap.l),
            const Row(children: [
              Kpi(value: '3', label: 'جولات'),
              Kpi(value: '1:51', unit: 'س', label: 'الزمن'),
              Kpi(value: '6:04', unit: '/كم', label: 'السرعة'),
            ]),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHead('آخر 8 أسابيع'),
            SizedBox(height: 130, child: _Bars(values: w, goal: Demo.goalKm)),
          ]),
        ),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHead('آخر الجولات'),
        Card(
          child: Column(children: [
            for (final (name, when, km, t, pace) in Demo.runs)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.sand2,
                  child: const Icon(Icons.route, color: Brand.coral, size: 20),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: Text(when, style: TextStyle(color: p.muted, fontSize: 12.5)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${km.toStringAsFixed(2)} كم', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('$t · $pace', style: TextStyle(color: p.muted, fontSize: 12)),
                  ],
                ),
              ),
          ]),
        ),
      ]),
    ]);
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.goal});
  final List<double> values;
  final double goal;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.infinite,
        painter: _BarsPainter(values, goal, context.pal),
      );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.v, this.goal, this.p);
  final List<double> v;
  final double goal;
  final Palette p;

  @override
  void paint(Canvas c, Size s) {
    final mx = math.max(v.reduce(math.max), goal);
    final n = v.length, gap = 10.0;
    final bw = (s.width - gap * (n - 1)) / n;
    final h = s.height - 18;
    // RTL: newest week on the left, matching Arabic reading of time.
    for (var i = 0; i < n; i++) {
      final x = s.width - (i + 1) * bw - i * gap;
      final bh = math.max(3.0, v[i] / mx * h);
      final last = i == n - 1;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, 18 + h - bh, bw, bh), const Radius.circular(5)),
        Paint()..color = last ? Brand.coral : Brand.sea.withValues(alpha: .45),
      );
      if (last) {
        final tp = TextPainter(
          text: TextSpan(text: '${v[i]}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.ink)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(x + bw / 2 - tp.width / 2, 18 + h - bh - 14));
      }
    }
    final gy = 18 + h - goal / mx * h;
    final dash = Paint()
      ..color = Brand.coral.withValues(alpha: .7)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 7) {
      c.drawLine(Offset(x, gy), Offset(math.min(x + 3, s.width), gy), dash);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.v != v || o.p != p;
}
