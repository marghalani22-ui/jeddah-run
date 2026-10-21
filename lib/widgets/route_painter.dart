import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws a run's route scaled to fit the box, keeping its true shape.
class RoutePainter extends CustomPainter {
  RoutePainter(
    this.path, {
    this.color = Colors.white,
    this.width = 5,
    this.glow = false,
    this.shadow = false,
    this.dots = true,
    this.padding = 0.08,
  });

  /// [lat, lng] pairs.
  final List<List<double>> path;
  final Color color;
  final double width, padding;
  final bool glow, shadow, dots;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = _project(size);
    if (pts.length < 2) return;
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (shadow) {
      canvas.drawPath(p.shift(const Offset(0, 2)), stroke(Colors.black.withValues(alpha: .35), width + 2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    if (glow) {
      canvas.drawPath(p, stroke(color.withValues(alpha: .45), width * 3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    canvas.drawPath(p, stroke(color, width));
    if (dots) {
      final r = width * 1.25;
      canvas.drawCircle(pts.first, r + 2, Paint()..color = Colors.white);
      canvas.drawCircle(pts.first, r, Paint()..color = const Color(0xFF2FB36C));
      canvas.drawCircle(pts.last, r + 2, Paint()..color = Colors.white);
      canvas.drawCircle(pts.last, r, Paint()..color = const Color(0xFFF25C2C));
    }
  }

  List<Offset> _project(Size size) {
    if (path.length < 2) return const [];
    // Thin very long paths; the shape is unchanged at image resolution.
    final step = math.max(1, path.length ~/ 1500);
    final src = [for (var i = 0; i < path.length; i += step) path[i], path.last];
    final midLat = src.fold(0.0, (a, e) => a + e[0]) / src.length;
    final k = math.cos(midLat * math.pi / 180);
    final xs = src.map((e) => e[1] * k).toList(), ys = src.map((e) => -e[0]).toList();
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final w = math.max(maxX - minX, 1e-9), h = math.max(maxY - minY, 1e-9);
    final pad = size.shortestSide * padding;
    final s = math.min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h);
    final ox = (size.width - w * s) / 2, oy = (size.height - h * s) / 2;
    return [for (var i = 0; i < xs.length; i++) Offset(ox + (xs[i] - minX) * s, oy + (ys[i] - minY) * s)];
  }

  @override
  bool shouldRepaint(RoutePainter o) => o.path != path || o.color != color || o.width != width || o.glow != glow;
}
