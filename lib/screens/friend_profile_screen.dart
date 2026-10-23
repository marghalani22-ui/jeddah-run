import 'package:flutter/material.dart';

import '../services/social.dart';
import '../state/game.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/friend_avatar.dart';
import '../widgets/game_widgets.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

/// A friend's card: level, numbers, a head-to-head with you, and their badges.
class FriendProfileScreen extends StatelessWidget {
  const FriendProfileScreen({super.key, required this.uid});
  final String uid;

  Future<void> _unfriend(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('تحذف $name من أصحابك؟'),
        content: const Text('تنقفل المحادثة بينكم، وتقدرون ترجعون أصحاب بطلب جديد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('احذف', style: TextStyle(color: c.pal.bad))),
        ],
      ),
    );
    if (ok != true) return;
    for (final f in social.friendships.where((f) => f.other == uid).toList()) {
      await social.remove(f);
    }
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: social,
        builder: (context, _) {
          final p = context.pal, pr = social.profiles[uid];
          final name = pr?.name ?? '…';
          final isFriend = social.friendships.any((f) => f.other == uid && f.state == FriendState.friends);
          final myName = settings.name.isEmpty ? 'أنت' : settings.name;
          return Scaffold(
            body: CustomScrollView(slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 250,
                backgroundColor: p.sand,
                actions: [
                  if (isFriend)
                    PopupMenuButton<String>(
                      onSelected: (_) => _unfriend(context, name),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'x', child: ListTile(leading: Icon(Icons.person_remove_outlined, color: p.bad), title: Text('حذف من الأصحاب', style: TextStyle(color: p.bad)))),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(gradient: Grad.night),
                    child: SafeArea(
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        FriendAvatar(name: name, size: 96, ring: (pr?.weekKm ?? 0) > 0),
                        const SizedBox(height: Gap.s),
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        if ((pr?.code ?? '').isNotEmpty)
                          Text('@${pr!.code}', textDirection: TextDirection.ltr, style: const TextStyle(color: Color(0xFFA9B3C7))),
                        const SizedBox(height: Gap.s),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(gradient: Grad.sunset, borderRadius: BorderRadius.circular(Radii.chip)),
                          child: Text('المستوى ${pr?.level ?? 1} · ${levelTitle(pr?.level ?? 1)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        const SizedBox(height: Gap.l),
                      ]),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.xxl),
                sliver: SliverList.list(children: [
                  if (isFriend)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUid: uid))),
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const Text('دردش'),
                    ),
                  const SizedBox(height: Gap.l),
                  KpiCard(children: [
                    Kpi(value: fmtKm(pr?.totalKm ?? 0), unit: 'كم', label: 'المجموع'),
                    Kpi(value: '${pr?.runs ?? 0}', label: 'جولة'),
                    Kpi(value: '${pr?.streak ?? 0}', unit: '🔥', label: 'السلسلة'),
                  ]),
                  const SizedBox(height: Gap.l),
                  const SectionHead('أنت ضدّه'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.l),
                      child: Column(children: [
                        Row(children: [
                          const UserAvatar(size: 34, shadow: false),
                          const SizedBox(width: Gap.s),
                          Expanded(child: Text(myName, style: TextStyle(fontWeight: FontWeight.w700, color: p.ink))),
                          Expanded(child: Text(name, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w700, color: p.ink))),
                          const SizedBox(width: Gap.s),
                          FriendAvatar(name: name, size: 34),
                        ]),
                        const SizedBox(height: Gap.m),
                        _Versus(label: 'هالأسبوع', unit: 'كم', me: runStore.weekKm, them: pr?.weekKm ?? 0),
                        _Versus(label: 'المجموع', unit: 'كم', me: runStore.totalKm, them: pr?.totalKm ?? 0),
                        _Versus(label: 'أطول جولة', unit: 'كم', me: runStore.longest?.km ?? 0, them: pr?.longestKm ?? 0),
                        _Versus(label: 'أطول سلسلة', unit: 'يوم', me: runStore.bestStreak.toDouble(), them: (pr?.bestStreak ?? 0).toDouble(), whole: true),
                        _Versus(label: 'المستوى', unit: '', me: game.level.$1.toDouble(), them: (pr?.level ?? 1).toDouble(), whole: true),
                      ]),
                    ),
                  ),
                  const SizedBox(height: Gap.l),
                  SectionHead('أوسمته', trailing: '${pr?.badges.length ?? 0} من ${badgeDefs.length}'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.s, Gap.l, Gap.s, Gap.s),
                      child: BadgeGrid(earned: pr?.badges ?? const {}, progressOf: (_) => 0),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        },
      );
}

/// One head-to-head line: my bar grows from the start, theirs from the end.
class _Versus extends StatelessWidget {
  const _Versus({required this.label, required this.unit, required this.me, required this.them, this.whole = false});
  final String label, unit;
  final double me, them;
  final bool whole;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final total = me + them;
    final share = total == 0 ? .5 : me / total;
    String f(double v) => whole ? v.round().toString() : fmtKm(v);
    final win = me > them ? 0 : (them > me ? 1 : -1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(children: [
        Row(children: [
          Text(f(me), style: TextStyle(fontWeight: FontWeight.w800, color: win == 0 ? Brand.coral : p.ink)),
          Expanded(child: Text('$label${unit.isEmpty ? '' : ' ($unit)'}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.muted))),
          Text(f(them), style: TextStyle(fontWeight: FontWeight.w800, color: win == 1 ? Brand.sea : p.ink)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              Expanded(flex: (share * 1000).round().clamp(1, 999), child: Container(color: Brand.coral)),
              const SizedBox(width: 2),
              Expanded(flex: ((1 - share) * 1000).round().clamp(1, 999), child: Container(color: Brand.sea)),
            ]),
          ),
        ),
      ]),
    );
  }
}
