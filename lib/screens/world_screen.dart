import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Map tab. The real MapLibre map arrives in step 6; for now a placeholder
/// fills the screen and the weekly summary opens as a bottom sheet.
class WorldScreen extends StatelessWidget {
  const WorldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Stack(children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.sand, p.sand2],
            ),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.map_outlined, size: 56, color: p.muted),
              const SizedBox(height: Gap.s),
              Text('خريطة جدة', style: Theme.of(context).textTheme.titleLarge),
              Text('تنضاف في المرحلة القادمة', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.l),
          child: Row(children: [
            _Chip(icon: Icons.local_fire_department, text: '${Demo.streak}', color: Brand.coral),
            const SizedBox(width: Gap.s),
            _Chip(icon: Icons.toll, text: '${Demo.balance}', color: Brand.sun),
            const Spacer(),
            IconButton.filledTonal(
              onPressed: () => _openWeek(context),
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'أسبوعك',
            ),
          ]),
        ),
      ),
      Positioned(
        left: Gap.l,
        right: Gap.l,
        bottom: Gap.l,
        child: FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.directions_run),
          label: const Text('ابدأ جولة'),
        ),
      ),
    ]);
  }

  void _openWeek(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: context.pal.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      builder: (_) => const _WeekSheet(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.card.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: p.edge),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _WeekSheet extends StatelessWidget {
  const _WeekSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('جولة اليوم؟', style: Theme.of(context).textTheme.titleLarge),
        Text('${Demo.streak} أيام متتالية', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gap.l),
        Ring(
          value: Demo.weekKm / Demo.goalKm,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${Demo.weekKm}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            Text('من ${Demo.goalKm.toInt()} كم', style: TextStyle(fontSize: 12, color: p.muted)),
          ]),
        ),
        const SizedBox(height: Gap.l),
        Card(
          child: Column(children: [
            for (final (name, prog, pts) in Demo.daily)
              ListTile(
                leading: SizedBox(
                  width: 26,
                  height: 26,
                  child: prog >= 1
                      ? const CircleAvatar(backgroundColor: Brand.leaf, child: Icon(Icons.check, size: 16, color: Colors.white))
                      : CircularProgressIndicator(value: prog, strokeWidth: 3, color: Brand.leaf, backgroundColor: p.sand2),
                ),
                title: Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                trailing: Text('+$pts', style: TextStyle(color: p.good, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        const SizedBox(height: Gap.l),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('ابدأ جولة')),
      ]),
    );
  }
}
