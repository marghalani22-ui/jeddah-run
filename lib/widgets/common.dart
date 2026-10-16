import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A big number with a small unit and a label under it.
class Kpi extends StatelessWidget {
  const Kpi({super.key, required this.value, this.unit = '', required this.label, this.color});

  final String value, unit, label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Expanded(
      child: Column(
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color ?? p.ink),
              ),
              if (unit.isNotEmpty)
                TextSpan(text: ' $unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.muted)),
            ]),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
        ],
      ),
    );
  }
}

class KpiRow extends StatelessWidget {
  const KpiRow({super.key, required this.children});
  final List<Kpi> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(children: children),
        ),
      );
}

/// Section header: title on the start side, optional action on the end.
class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.s),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: Brand.coral))),
        ]),
      );
}

/// Progress ring used for the weekly goal.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, this.size = 132, this.stroke = 12, this.color = Brand.leaf, this.child});
  final double value, size, stroke;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(value.clamp(0, 1), stroke, color, context.pal.sand2),
          child: Center(child: child),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.w, this.c, this.track);
  final double v, w;
  final Color c, track;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(w / 2, w / 2, s.width - w, s.height - w);
    final pt = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, pt..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, pt..color = c);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.c != c || o.track != track;
}

/// Thin horizontal progress bar.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color = Brand.coral, this.height = 8});
  final double value, height;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          color: color,
          backgroundColor: context.pal.sand2,
        ),
      );
}

/// A settings-style row inside a card list.
class RowTile extends StatelessWidget {
  const RowTile({super.key, required this.icon, required this.label, this.value, this.onTap});
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: p.ink),
      title: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (value != null) Text(value!, style: TextStyle(fontSize: 13, color: p.muted)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_left, size: 18, color: p.muted),
      ]),
    );
  }
}

/// Standard padded, scrollable page body.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.xxl),
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: Gap.xl),
              children[i],
            ]
          ],
        ),
      );
}
