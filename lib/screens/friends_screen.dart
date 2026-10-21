import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/cloud.dart';
import '../services/social.dart';
import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';

/// Friends tab: your @username, add by username, requests, and a weekly
/// leaderboard of friends that doubles as the chat list.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([cloud, social]),
        builder: (context, _) {
          if (cloud.user == null) {
            return PageBody(title: 'الأصحاب', children: [
              const EmptyState(
                icon: Icons.group_outlined,
                title: 'جري أحلى مع أصحابك',
                hint: 'سجّل دخول بحساب قوقل عشان تضيف أصحابك، تشوف ترتيبكم كل أسبوع، وتسولفون.',
              ),
              FilledButton.icon(
                onPressed: cloud.busy || !cloud.ready ? null : () => cloud.signIn(),
                icon: const Icon(Icons.login),
                label: const Text('الدخول بحساب قوقل'),
              ),
            ]);
          }
          if ((social.mine?.code ?? '').isEmpty) return const _PickUsername();
          return const _Friends();
        },
      );
}

class _PickUsername extends StatefulWidget {
  const _PickUsername();

  @override
  State<_PickUsername> createState() => _PickUsernameState();
}

class _PickUsernameState extends State<_PickUsername> {
  final _ctl = TextEditingController();
  String? _err;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final e = await social.setUsername(_ctl.text);
    if (!mounted) return;
    setState(() {
      _err = e;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) => PageBody(title: 'الأصحاب', children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('اختر اسم المستخدم', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('أصحابك يضيفونك فيه. حروف إنجليزية وأرقام، من 3 إلى 16.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Gap.m),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _ctl,
                  autofocus: true,
                  maxLength: 16,
                  decoration: InputDecoration(prefixText: '@', hintText: 'hassan_runs', errorText: _err, border: const OutlineInputBorder()),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: Gap.s),
              FilledButton(onPressed: _busy ? null : _save, child: const Text('احفظ')),
            ]),
          ),
        ),
      ]);
}

class _Friends extends StatefulWidget {
  const _Friends();

  @override
  State<_Friends> createState() => _FriendsState();
}

class _FriendsState extends State<_Friends> {
  final _add = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    social.refreshProfiles();
  }

  Future<void> _sendRequest() async {
    if (_add.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final msg = await social.addFriend(_add.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (msg == 'انرسل الطلب' || msg == 'صرتوا أصحاب') _add.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, me = social.mine!;
    final incoming = social.friendships.where((f) => f.state == FriendState.pendingIn).toList();
    final outgoing = social.friendships.where((f) => f.state == FriendState.pendingOut).toList();
    final friends = social.friendships.where((f) => f.state == FriendState.friends).toList();

    // Weekly leaderboard: friends plus me, by distance this week.
    final board = <(String uid, Profile? prof, bool isMe)>[
      (me.uid, me, true),
      for (final f in friends) (f.other, social.profiles[f.other], false),
    ]..sort((a, b) {
        final ka = a.$3 ? runStore.weekKm : (a.$2?.weekKm ?? 0);
        final kb = b.$3 ? runStore.weekKm : (b.$2?.weekKm ?? 0);
        return kb.compareTo(ka);
      });

    return RefreshIndicator(
      onRefresh: social.refreshProfiles,
      child: PageBody(title: 'الأصحاب', children: [
        Container(
          padding: const EdgeInsets.all(Gap.l),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF22335A), Color(0xFF0E1525)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('اسمك في لفّة', style: TextStyle(color: Color(0xFFA9B3C7), fontSize: 12.5)),
                Text('@${me.code}', textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              ]),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Share.share('ضيفني في تطبيق لفّة وخلنا نجري سوا 🏃\nاسمي: @${me.code}'),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('ادعُ صاحبك'),
            ),
          ]),
        ),
        Row(children: [
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _add,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendRequest(),
                decoration: InputDecoration(
                  prefixText: '@',
                  hintText: 'اسم المستخدم',
                  filled: true,
                  fillColor: p.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.btn), borderSide: BorderSide(color: p.edge)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.btn), borderSide: BorderSide(color: p.edge)),
                ),
              ),
            ),
          ),
          const SizedBox(width: Gap.s),
          SizedBox(
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(80, 56)),
              onPressed: _sending ? null : _sendRequest,
              child: const Text('أضف'),
            ),
          ),
        ]),
        if (incoming.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHead('طلبات صداقة', trailing: '${incoming.length}'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final f in incoming)
                  ListTile(
                    leading: _Avatar(name: social.profiles[f.other]?.name ?? '؟'),
                    title: Text(social.profiles[f.other]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('@${social.profiles[f.other]?.code ?? ''}', textDirection: TextDirection.ltr, textAlign: TextAlign.right),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(onPressed: () => social.remove(f), icon: Icon(Icons.close, color: p.muted), tooltip: 'رفض'),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Brand.coral),
                        onPressed: () => social.accept(f),
                        icon: const Icon(Icons.check, color: Colors.white),
                        tooltip: 'قبول',
                      ),
                    ]),
                  ),
              ]),
            ),
          ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHead('ترتيب الأسبوع', trailing: 'كم'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < board.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                _BoardRow(rank: i + 1, uid: board[i].$1, prof: board[i].$2, isMe: board[i].$3),
              ],
            ]),
          ),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.m),
              child: Text('أضف أصحابك باسم المستخدم، أو أرسل لهم دعوة، وتنافسوا على المركز الأول كل أسبوع.',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ),
        ]),
        if (outgoing.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionHead('طلبات أرسلتها'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final f in outgoing)
                  ListTile(
                    leading: _Avatar(name: social.profiles[f.other]?.name ?? '؟'),
                    title: Text(social.profiles[f.other]?.name ?? '…'),
                    subtitle: const Text('ننتظر موافقته'),
                    trailing: TextButton(onPressed: () => social.remove(f), child: const Text('إلغاء')),
                  ),
              ]),
            ),
          ]),
      ]),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.rank, required this.uid, required this.prof, required this.isMe});
  final int rank;
  final String uid;
  final Profile? prof;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final name = isMe ? 'أنت' : (prof?.name ?? '…');
    final km = isMe ? runStore.weekKm : (prof?.weekKm ?? 0);
    final streak = isMe ? runStore.streak : (prof?.streak ?? 0);
    final chatId = social.me == null ? '' : pairId(social.me!, uid);
    final unread = !isMe && social.isUnread(chatId);
    final last = social.chats[chatId];
    final medal = rank <= 3 ? const [Color(0xFFFFB81C), Color(0xFFB7BDC9), Color(0xFFD08A4E)][rank - 1] : null;
    return ListTile(
      tileColor: isMe ? Brand.coral.withValues(alpha: .06) : null,
      onTap: isMe
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(otherUid: uid))),
      leading: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 26,
          child: medal != null
              ? CircleAvatar(radius: 12, backgroundColor: medal, child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))
              : Text('$rank', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: Gap.s),
        _Avatar(name: isMe ? (social.mine?.name ?? 'أ') : (prof?.name ?? '؟')),
      ]),
      title: Text(name, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Text(
        isMe ? (streak > 0 ? '$streak أيام متتالية' : 'ابدأ سلسلتك اليوم') : (last != null ? last.lastText : (streak > 0 ? '$streak أيام متتالية' : 'اضغط للسوالف')),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: unread ? p.ink : p.muted, fontSize: 12.5, fontWeight: unread ? FontWeight.w600 : FontWeight.w400),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (unread) const Padding(padding: EdgeInsetsDirectional.only(end: 8), child: CircleAvatar(radius: 5, backgroundColor: Brand.coral)),
        Text(fmtKm(km), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.ink)),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  static const _colors = [Color(0xFFF25C2C), Color(0xFF0B6E8A), Color(0xFF4B2FC9), Color(0xFF2FB36C), Color(0xFFE0A92E)];

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 20,
        backgroundColor: _colors[name.hashCode.abs() % _colors.length],
        child: Text(name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
}
