import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/runs.dart';
import '../theme/tokens.dart';

/// Pace per kilometre as a smooth area: faster is higher.
/// Kilometre 1 sits on the right (RTL reading order).
class PaceChart extends StatelessWidget {
  const PaceChart({super.key, required this.splits});
  final List<int> splits;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final avg = splits.fold(0, (a, b) => a + b) / splits.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.m, Gap.l, Gap.m, Gap.s),
        child: Column(children: [
          SizedBox(height: 150, child: CustomPaint(size: Size.infinite, painter: _PacePainter(splits, avg, p))),
          const SizedBox(height: Gap.xs),
          Row(children: [
            Container(width: 14, height: 2, color: p.muted),
            const SizedBox(width: 6),
            Text('المتوسط ${fmtPace(avg)}', style: TextStyle(fontSize: 12, color: p.muted)),
            const Spacer(),
            const Icon(Icons.circle, size: 9, color: Brand.coral),
            const SizedBox(width: 6),
            Text('أسرع كيلو', style: TextStyle(fontSize: 12, color: p.muted)),
          ]),
        ]),
      ),
    );
  }
}

class _PacePainter extends CustomPainter {
  _PacePainter(this.v, this.avg, this.p);
  final List<int> v;
  final double avg;
  final Palette p;

  @override
  void paint(Canvas c, Size s) {
    const top = 22.0, bottom = 20.0, side = 14.0;
    final h = s.height - top - bottom, w = s.width - side * 2;
    final fast = v.reduce(math.min).toDouble(), slow = v.reduce(math.max).toDouble();
    final span = math.max(slow - fast, 20.0);
    final lo = fast - span * .25, hi = slow + span * .25;
    double y(num sec) => top + (sec - lo) / (hi - lo) * h; // faster → smaller y → higher
    double x(int i) => s.width - side - (v.length == 1 ? w / 2 : i / (v.length - 1) * w);

    final pts = [for (var i = 0; i < v.length; i++) Offset(x(i), y(v[i]))];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i], mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, top + h)
      ..lineTo(pts.first.dx, top + h)
      ..close();
    final rect = Rect.fromLTWH(0, top, s.width, h);
    c.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Brand.coral.withValues(alpha: .35), Brand.sun.withValues(alpha: .02)],
        ).createShader(rect),
    );

    // Average line, dashed.
    final ay = y(avg);
    final dash = Paint()
      ..color = p.muted.withValues(alpha: .7)
      ..strokeWidth = 1;
    for (double dx = side; dx < s.width - side; dx += 7) {
      c.drawLine(Offset(dx, ay), Offset(math.min(dx + 3, s.width - side), ay), dash);
    }

    c.drawPath(
      line,
      Paint()
        ..shader = Grad.sunset.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final fi = v.indexOf(fast.toInt());
    for (var i = 0; i < pts.length; i++) {
      final best = i == fi;
      c.drawCircle(pts[i], best ? 6 : 3.5, Paint()..color = p.card);
      c.drawCircle(pts[i], best ? 4.5 : 2.5, Paint()..color = best ? Brand.coral : Brand.sun);
      // Kilometre labels under the chart; thin them out on long runs.
      final step = (v.length / 8).ceil();
      if (i % step == 0 || i == v.length - 1) _text(c, '${i + 1}', Offset(pts[i].dx, s.height - 14), p.muted, 10.5, FontWeight.w500);
    }
    _text(c, fmtPace(fast), Offset(pts[fi].dx, pts[fi].dy - 19), p.ink, 11, FontWeight.w700);
  }

  void _text(Canvas c, String t, Offset at, Color color, double size, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: size, fontWeight: weight, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(_PacePainter o) => o.v != v || o.p != p;
}
