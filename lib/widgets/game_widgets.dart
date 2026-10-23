import 'package:flutter/material.dart';

import '../state/game.dart';
import '../theme/tokens.dart';

/// "تحديات اليوم 1/3" pill on the home screen; opens the challenges sheet.
class ChallengesPill extends StatelessWidget {
  const ChallengesPill({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal, today = DateTime.now();
    final list = game.challengesFor(today);
    final done = list.where((c) => game.challengeDone(c, today)).length;
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(Radii.chip),
      elevation: 3,
      shadowColor: const Color(0x3314213D),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.chip),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          backgroundColor: p.card,
          builder: (_) => const ChallengesSheet(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ShaderMask(
              shaderCallback: (r) => Grad.sunset.createShader(r),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 6),
            Text('تحديات اليوم', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: p.ink)),
            const SizedBox(width: 6),
            Text('$done/${list.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Brand.coral)),
          ]),
        ),
      ),
    );
  }
}

class ChallengesSheet extends StatelessWidget {
  const ChallengesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal, today = DateTime.now();
    final list = game.challengesFor(today);
    final days = game.activeDaysThisWeek;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('تحديات اليوم', style: Theme.of(context).textTheme.titleLarge),
          Text('تتجدد الساعة 12 بالليل · نقاطها فوق حد الـ 300 اليومي', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Gap.m),
          for (final c in list) _ChallengeRow(c: c, day: today),
          const SizedBox(height: Gap.m),
          Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(gradient: Grad.night, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const Icon(Icons.event_available, color: Brand.sun),
              const SizedBox(width: Gap.s),
              const Expanded(
                child: Text('تحدي الأسبوع: اجرِ 4 أيام مختلفة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              Text(game.weeklyDone ? '✓ +60' : '${days.clamp(0, 4)}/4 · +60',
                  style: TextStyle(color: game.weeklyDone ? const Color(0xFF4ADE8B) : Brand.sun, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: Gap.s),
          Text('مكافأة السلسلة: أول جولة كيلو أو أكثر كل يوم تعطيك 5 نقاط × أيام سلسلتك (لين 50).',
              style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5)),
        ]),
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.c, required this.day});
  final Challenge c;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final done = game.challengeDone(c, day);
    final prog = done ? 1.0 : game.challengeProgress(c, day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: done ? Grad.sunset : null,
            color: done ? null : p.sand2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(done ? Icons.check_rounded : c.icon, color: done ? Colors.white : p.ink),
        ),
        const SizedBox(width: Gap.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: TextStyle(fontWeight: FontWeight.w600, color: p.ink, decoration: done ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: prog, minHeight: 6, color: Brand.coral, backgroundColor: p.sand2),
            ),
          ]),
        ),
        const SizedBox(width: Gap.m),
        Text('+${c.points}', style: TextStyle(fontWeight: FontWeight.w800, color: done ? p.good : Brand.coral)),
      ]),
    );
  }
}

/// Level + XP bar card used in the profile.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key});

  @override
  Widget build(BuildContext context) {
    final (lv, into, need) = game.level;
    return Container(
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(gradient: Grad.night, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(gradient: Grad.sunset, shape: BoxShape.circle),
          child: Text('$lv', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: Gap.l),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المستوى $lv · ${levelTitle(lv)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: into / need, minHeight: 8, color: Brand.sun, backgroundColor: const Color(0x33FFFFFF)),
            ),
            const SizedBox(height: 6),
            Text('${need - into} خبرة للمستوى ${lv + 1}', style: const TextStyle(color: Color(0xFFA3AEC6), fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

/// Badge grid: unlocked in colour, locked in grey with progress.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.progressOf, this.earned});
  final double Function(BadgeDef b) progressOf;

  /// Whose badges to show; defaults to mine.
  final Set<String>? earned;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, mine = earned ?? game.badges.toSet();
    final sorted = [...badgeDefs]..sort((a, b) => (mine.contains(b.id) ? 1 : 0).compareTo(mine.contains(a.id) ? 1 : 0));
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Gap.m,
      crossAxisSpacing: Gap.s,
      childAspectRatio: .72,
      children: [
        for (final b in sorted)
          Builder(builder: (context) {
            final on = mine.contains(b.id);
            final prog = on ? 1.0 : progressOf(b);
            return Tooltip(
              message: '${b.title}: ${b.hint} · +${b.points}',
              triggerMode: TooltipTriggerMode.tap,
              child: Column(children: [
                Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 62,
                    height: 62,
                    child: CircularProgressIndicator(
                      value: prog,
                      strokeWidth: 3,
                      color: on ? b.color : Brand.coral.withValues(alpha: .6),
                      backgroundColor: p.sand2,
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? b.color : p.sand2,
                      boxShadow: on ? [BoxShadow(color: b.color.withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 4))] : null,
                    ),
                    child: Icon(on ? b.icon : Icons.lock_outline_rounded, color: on ? Colors.white : p.muted, size: 24),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(b.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(fontSize: 11.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? p.ink : p.muted)),
              ]),
            );
          }),
      ],
    );
  }
}
