import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/phase.dart';

/// Sky band for the top of the home screen: gradient, sun or moon on its
/// arc, a few drifting clouds by day and twinkling stars at night.
class SkyBand extends StatefulWidget {
  const SkyBand({super.key, required this.phase, this.height = 200});
  final Phase phase;
  final double height;

  @override
  State<SkyBand> createState() => _SkyBandState();
}

class _SkyBandState extends State<SkyBand> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              layoutBuilder: (cur, prev) => Stack(fit: StackFit.expand, children: [...prev, if (cur != null) cur]),
              child: AnimatedBuilder(
                key: ValueKey(widget.phase),
                animation: _a,
                builder: (_, __) => CustomPaint(size: Size.infinite, painter: SkyPainter(widget.phase, _a.value, phaseClock.dayProgress)),
              ),
            ),
          ),
        ),
      );
}

class SkyPainter extends CustomPainter {
  SkyPainter(this.phase, this.t, this.dayProgress);
  final Phase phase;
  final double t, dayProgress;

  @override
  void paint(Canvas c, Size s) {
    final sky = skyOf(phase);
    final rect = Offset.zero & s;
    // Gradient that fades out at the bottom so the map shows through.
    c.saveLayer(rect, Paint());
    c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky).createShader(rect));
    c.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, .55, 1],
        ).createShader(rect),
    );

    final w = s.width, h = s.height;
    if (phase == Phase.night) {
      final rnd = math.Random(7);
      for (var i = 0; i < 46; i++) {
        final x = rnd.nextDouble() * w, y = rnd.nextDouble() * h * .6, r = .6 + rnd.nextDouble() * 1.2;
        final tw = .45 + .55 * (0.5 + 0.5 * math.sin((t + i / 46) * 2 * math.pi));
        c.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: tw * .9));
      }
      final m = Offset(w * .78, h * .22);
      c.drawCircle(m, 30, Paint()..color = const Color(0x33FFF3D6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      c.drawCircle(m, 15, Paint()..color = const Color(0xFFFFF3D6));
      c.drawCircle(m + const Offset(6, -4), 13, Paint()..color = sky[1]);
    } else {
      // Sun on an arc: low and warm at sunrise/sunset, high at midday.
      final p = phase == Phase.sunrise ? 0.08 : phase == Phase.sunset ? 0.92 : dayProgress.clamp(0.15, 0.85);
      final x = w * (0.12 + 0.76 * p);
      final y = h * (0.62 - 0.48 * math.sin(p * math.pi));
      final sunCol = phase == Phase.day ? const Color(0xFFFFE08A) : const Color(0xFFFFB81C);
      c.drawCircle(Offset(x, y), 46, Paint()..color = sunCol.withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26));
      c.drawCircle(Offset(x, y), 18, Paint()..color = sunCol);
      if (phase != Phase.sunset) {
        final cloud = Paint()..color = Colors.white.withValues(alpha: phase == Phase.day ? .85 : .6);
        for (final (cx, cy, k) in [(.2, .28, 1.0), (.62, .16, .8), (.9, .4, .7)]) {
          final ox = ((cx + t * .08) % 1.1 - .05) * w, oy = cy * h;
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(ox, oy), width: 70 * k, height: 18 * k), Radius.circular(9 * k)), cloud);
          c.drawCircle(Offset(ox - 8 * k, oy - 8 * k), 12 * k, cloud);
          c.drawCircle(Offset(ox + 10 * k, oy - 6 * k), 9 * k, cloud);
        }
      } else {
        // Sunset: soft horizon glow.
        c.drawRect(Rect.fromLTWH(0, h * .45, w, h * .2),
            Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFB81C), Color(0x55FFB81C), Color(0x00FFB81C)]).createShader(Rect.fromLTWH(0, h * .45, w, h * .2)));
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(SkyPainter o) => true;
}
