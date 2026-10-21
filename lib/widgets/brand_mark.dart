import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Laffa mark: an endless running loop (figure eight) in the sunset
/// gradient, with the runner as a dot at the start of the left lobe.
class LaffaMark extends StatelessWidget {
  const LaffaMark({super.key, this.width = 40, this.runner = Colors.white, this.color});

  final double width;
  final Color? runner;

  /// Solid stroke colour; null draws the sunset gradient.
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * .75), painter: _MarkPainter(runner, color));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.runner, this.color);
  final Color? runner, color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 120;
    canvas.save();
    canvas.scale(k);
    canvas.translate(60, 45);
    canvas.rotate(-8 * math.pi / 180);
    canvas.translate(-60, -45);
    final path = Path()
      ..moveTo(60, 45)
      ..cubicTo(50, 25, 10, 20, 10, 45)
      ..cubicTo(10, 70, 50, 66, 60, 45)
      ..cubicTo(70, 24, 102, 28, 106, 45)
      ..cubicTo(110, 62, 74, 62, 60, 45)
      ..close();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (color != null) {
      stroke.color = color!;
    } else {
      stroke.shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFF25C2C), Color(0xFFFFB81C)],
      ).createShader(const Rect.fromLTWH(0, 0, 120, 90));
    }
    canvas.drawPath(path, stroke);
    if (runner != null) canvas.drawCircle(const Offset(10, 45), 8, Paint()..color = runner!);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.runner != runner || o.color != color;
}
