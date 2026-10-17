import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A big number with a small unit and a label under it.
class Kpi extends StatelessWidget {
  const Kpi({super.key, required this.value, this.unit = '', required this.label, this.big = false});

  final String value, unit, label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Expanded(
      child: Column(children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: value, style: TextStyle(fontSize: big ? 30 : 21, fontWeight: FontWeight.w700, color: p.ink)),
            if (unit.isNotEmpty)
              TextSpan(text: ' $unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.muted)),
          ]),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
      ]),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.children});
  final List<Kpi> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(children: children),
        ),
      );
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.s),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color = Brand.coral, this.height = 8});
  final double value, height;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          minHeight: height,
          color: color,
          backgroundColor: context.pal.sand2,
        ),
      );
}

/// Friendly empty state with an icon, a title and a hint.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.hint});
  final IconData icon;
  final String title, hint;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(children: [
          CircleAvatar(radius: 28, backgroundColor: p.sand2, child: Icon(icon, color: Brand.coral, size: 28)),
          const SizedBox(height: Gap.m),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(hint, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.xxl),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            for (final c in children) ...[const SizedBox(height: Gap.xl), c],
          ],
        ),
      );
}
