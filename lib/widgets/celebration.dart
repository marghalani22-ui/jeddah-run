import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Full-screen celebration with falling confetti.
Future<void> celebrate(BuildContext context, {required IconData icon, required String title, required String subtitle, Color color = Brand.coral}) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'احتفال',
    barrierColor: const Color(0xCC0E1525),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
    ),
    pageBuilder: (context, _, __) => _Celebration(icon: icon, title: title, subtitle: subtitle, color: color),
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.icon, required this.title, required this.subtitle, required this.color});
  final IconData icon;
  final String title, subtitle;
  final Color color;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  final _pieces = List.generate(90, (i) => _Piece(math.Random(i)));

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(animation: _a, builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_pieces, _a.value))),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .55), blurRadius: 40, spreadRadius: 4)],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 64),
                ),
                const SizedBox(height: 28),
                Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFCAD2E3), fontSize: 16, height: 1.5)),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: Grad.sunset, borderRadius: BorderRadius.circular(18)),
                    child: TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('كفو!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );
}

class _Piece {
  _Piece(math.Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * .35,
        speed = .7 + r.nextDouble() * .6,
        drift = (r.nextDouble() - .5) * .25,
        spin = (r.nextDouble() - .5) * 14,
        w = 6 + r.nextDouble() * 6,
        color = const [Color(0xFFF25C2C), Color(0xFFFFB81C), Color(0xFF12A4B8), Color(0xFF2FB36C), Color(0xFFB04BD9), Colors.white][r.nextInt(6)];
  final double x, delay, speed, drift, spin, w;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.p, this.t);
  final List<_Piece> p;
  final double t;

  @override
  void paint(Canvas c, Size s) {
    for (final q in p) {
      final lt = ((t - q.delay) / (1 - q.delay)).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final y = -20 + lt * q.speed * (s.height + 60);
      final x = (q.x + q.drift * lt + .02 * math.sin(lt * 12 + q.spin)) * s.width;
      c.save();
      c.translate(x, y);
      c.rotate(q.spin * lt);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: q.w, height: q.w * .5), const Radius.circular(1.5)),
        Paint()..color = q.color.withValues(alpha: lt > .85 ? (1 - lt) / .15 : 1),
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}
