import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/cloud.dart';
import '../services/social.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import '../widgets/friend_avatar.dart';
import '../widgets/gradient_button.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'friend_profile_screen.dart';

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
              GradientButton(
                onPressed: !cloud.ready ? null : () => cloud.signIn(),
                busy: cloud.busy,
                icon: Icons.login,
                label: 'الدخول بحساب قوقل',
              ),
            ]);
          }
          if ((social.mine?.code ?? '').isEmpty) return const _PickUsername();
          return const FriendsList();
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

/// The signed-in view (public so preview tests can render it without Firebase).
class FriendsList extends StatefulWidget {
  const FriendsList();

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    social.refreshProfiles();
    _search.addListener(() => setState(() {}));
  }

  bool _match(String uid) {
    final q = _search.text.trim().toLowerCase().replaceAll('@', '');
    if (q.isEmpty) return true;
    final pr = social.profiles[uid];
    return (pr?.name.toLowerCase().contains(q) ?? false) || (pr?.code.contains(q) ?? false);
  }

  void _openProfile(String uid) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FriendProfileScreen(uid: uid)));

  void _openChat(String uid) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(otherUid: uid)));

  @override
  Widget build(BuildContext context) {
    final p = context.pal, me = social.mine!;
    final incoming = social.friendships.where((f) => f.state == FriendState.pendingIn).toList();
    final outgoing = social.friendships.where((f) => f.state == FriendState.pendingOut).toList();
    final friends = social.friendships.where((f) => f.state == FriendState.friends).map((f) => f.other).toList();

    // Chats: most recent conversation first, then friends you haven't talked to.
    final chats = friends.where(_match).toList()
      ..sort((a, b) {
        final ta = social.chats[pairId(me.uid, a)]?.lastAt, tb = social.chats[pairId(me.uid, b)]?.lastAt;
        if (ta == null && tb == null) return (social.profiles[a]?.name ?? '').compareTo(social.profiles[b]?.name ?? '');
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

    // Weekly board for the top strip: me + friends by distance.
    final board = <(String, String, double, bool)>[
      (me.uid, settings.name.isEmpty ? me.name : settings.name, runStore.weekKm, true),
      for (final u in friends) (u, social.profiles[u]?.name ?? '…', social.profiles[u]?.weekKm ?? 0, false),
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    return ColoredBox(
      color: p.sand,
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            _Header(
              requests: incoming.length,
              searching: _searching,
              search: _search,
              onSearch: () => setState(() {
                _searching = !_searching;
                if (!_searching) _search.clear();
              }),
            ),
            Expanded(
              child: RefreshIndicator(
                color: Brand.coral,
                onRefresh: social.refreshProfiles,
                child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                  if (!_searching) _WeekStrip(board: board, onTap: _openProfile),
                  if (incoming.isNotEmpty) ...[
                    _Label('أضافوك', count: incoming.length),
                    for (final f in incoming) _RequestRow(f: f),
                  ],
                  _Label('المحادثات', count: chats.isEmpty ? null : chats.length),
                  if (chats.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, 0),
                      child: Column(children: [
                        Image.asset('assets/brand/rakood_waiting.png', width: 110, height: 110),
                        const SizedBox(height: Gap.s),
                        Text(_searching ? 'ما لقينا أحد بهذا الاسم' : 'ما عندك أصحاب للحين',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.ink)),
                        const SizedBox(height: 4),
                        Text('أضف أصحابك باسم المستخدم أو أرسل لهم دعوة، وتنافسوا كل أسبوع.',
                            textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
                        const SizedBox(height: Gap.m),
                        FilledButton.icon(
                          onPressed: () => showAddFriend(context),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('أضف صاحب'),
                        ),
                      ]),
                    )
                  else
                    for (var i = 0; i < chats.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 84, endIndent: Gap.l, color: p.edge),
                      _ChatRow(uid: chats[i], onTap: () => _openChat(chats[i]), onAvatar: () => _openProfile(chats[i])),
                    ],
                  if (outgoing.isNotEmpty) ...[
                    const _Label('طلبات أرسلتها'),
                    for (final f in outgoing)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.l),
                        leading: FriendAvatar(name: social.profiles[f.other]?.name ?? '؟', size: 44),
                        title: Text(social.profiles[f.other]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Row(children: [
                          Icon(Icons.hourglass_top_rounded, size: 14, color: p.muted),
                          const SizedBox(width: 4),
                          Text('ننتظر موافقته', style: TextStyle(color: p.muted, fontSize: 12.5)),
                        ]),
                        trailing: TextButton(onPressed: () => social.remove(f), child: Text('إلغاء', style: TextStyle(color: p.muted))),
                      ),
                  ],
                ]),
              ),
            ),
          ]),
          if (friends.isNotEmpty)
            PositionedDirectional(
              end: Gap.l,
              bottom: Gap.l,
              child: _NewChatButton(onPick: _openChat, friends: friends),
            ),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.requests, required this.searching, required this.search, required this.onSearch});
  final int requests;
  final bool searching;
  final TextEditingController search;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget round(IconData icon, VoidCallback onTap, {int badge = 0, String? tip}) => Tooltip(
          message: tip ?? '',
          child: InkResponse(
            onTap: onTap,
            radius: 24,
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: Brand.coral,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: p.sand2, shape: BoxShape.circle),
                child: Icon(icon, color: p.ink, size: 21),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.s),
      child: Column(children: [
        Row(children: [
          GestureDetector(onTap: () => showAddFriend(context), child: const UserAvatar(size: 40, shadow: false)),
          const SizedBox(width: Gap.s),
          round(searching ? Icons.close_rounded : Icons.search_rounded, onSearch, tip: 'بحث'),
          Expanded(
            child: Text('الأصحاب', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: p.ink)),
          ),
          const SizedBox(width: 48),
          round(Icons.person_add_alt_1_rounded, () => showAddFriend(context), badge: requests, tip: 'أضف صاحب'),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: searching
              ? Padding(
                  padding: const EdgeInsets.only(top: Gap.s),
                  child: TextField(
                    controller: search,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'دوّر بالاسم أو @اسم_المستخدم',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: p.sand2,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

/// Story-style strip: everyone's distance this week, ranked. A ring means they ran.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.board, required this.onTap});
  final List<(String, String, double, bool)> board;
  final void Function(String uid) onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    const medals = [Color(0xFFFFB81C), Color(0xFFB7BDC9), Color(0xFFD08A4E)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Label('ترتيب الأسبوع'),
      SizedBox(
        height: 116,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.l),
          itemCount: board.length,
          separatorBuilder: (_, __) => const SizedBox(width: Gap.m),
          itemBuilder: (_, i) {
            final (uid, name, km, isMe) = board[i];
            return GestureDetector(
              onTap: isMe ? null : () => onTap(uid),
              child: SizedBox(
                width: 68,
                child: Column(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: km > 0 ? Grad.sunset : null, color: km > 0 ? null : p.edge),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: p.sand),
                          child: const UserAvatar(size: 52, shadow: false),
                        ),
                      )
                    else
                      FriendAvatar(name: name, size: 52, ring: km > 0),
                    if (i < 3 && km > 0)
                      PositionedDirectional(
                        end: -2,
                        top: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: medals[i], shape: BoxShape.circle, border: Border.all(color: p.sand, width: 2)),
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(isMe ? 'أنت' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink)),
                  Text('${fmtKm(km)} كم', style: TextStyle(fontSize: 11, color: km > 0 ? Brand.coral : p.muted, fontWeight: FontWeight.w700)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.s),
        child: Row(children: [
          Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.pal.muted, letterSpacing: .2)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text('$count', style: TextStyle(fontSize: 13, color: context.pal.muted)),
          ],
        ]),
      );
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.f});
  final Friendship f;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, pr = social.profiles[f.other];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 6),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FriendProfileScreen(uid: f.other))),
          child: FriendAvatar(name: pr?.name ?? '؟', size: 48),
        ),
        const SizedBox(width: Gap.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pr?.name ?? '…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: p.ink)),
            Text('@${pr?.code ?? ''}', textDirection: TextDirection.ltr, style: TextStyle(color: p.muted, fontSize: 12.5)),
          ]),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => social.accept(f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(gradient: Grad.sunset, borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 17),
              SizedBox(width: 5),
              Text('قبول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        IconButton(onPressed: () => social.remove(f), icon: Icon(Icons.close_rounded, color: p.muted), tooltip: 'رفض'),
      ]),
    );
  }
}

/// One chat line: status icon (new / received / sent), time and the friend's running streak.
class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.uid, required this.onTap, required this.onAvatar});
  final String uid;
  final VoidCallback onTap, onAvatar;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, pr = social.profiles[uid];
    final chatId = pairId(social.me!, uid);
    final c = social.chats[chatId];
    final unread = social.isUnread(chatId);
    final (IconData icon, Color color, String label) = c == null || c.lastAt == null
        ? (Icons.chat_bubble_outline_rounded, p.muted, 'اضغط للسوالف')
        : c.lastFrom == social.me
            ? (Icons.near_me_rounded, Brand.sea, 'أرسلت')
            : unread
                ? (Icons.chat_bubble_rounded, Brand.coral, 'رسالة جديدة')
                : (Icons.chat_bubble_outline_rounded, Brand.coral, 'استلمت');
    final streak = pr?.streak ?? 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 10),
        child: Row(children: [
          GestureDetector(onTap: onAvatar, child: FriendAvatar(name: pr?.name ?? '؟', size: 54, ring: (pr?.weekKm ?? 0) > 0)),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pr?.name ?? '…', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: unread ? FontWeight.w800 : FontWeight.w700, color: p.ink)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(icon, size: 15, color: color, textDirection: TextDirection.ltr),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(fontSize: 12.5, color: unread ? Brand.coral : p.muted, fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
                if (c?.lastAt != null) Text(' · ${chatAgo(c!.lastAt)}', style: TextStyle(fontSize: 12.5, color: p.muted)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (streak > 0)
              Text('$streak 🔥', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: p.ink))
            else
              Icon(Icons.directions_run_rounded, size: 18, color: p.edge),
            const SizedBox(height: 2),
            Text('${fmtKm(pr?.weekKm ?? 0)} كم', style: TextStyle(fontSize: 11.5, color: p.muted)),
          ]),
        ]),
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onPick, required this.friends});
  final void Function(String uid) onPick;
  final List<String> friends;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final uid = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (c) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
                    child: Text('محادثة جديدة', style: Theme.of(c).textTheme.titleLarge),
                  ),
                  for (final u in friends)
                    ListTile(
                      leading: FriendAvatar(name: social.profiles[u]?.name ?? '؟', size: 42),
                      title: Text(social.profiles[u]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('@${social.profiles[u]?.code ?? ''}', textDirection: TextDirection.ltr, textAlign: TextAlign.right),
                      onTap: () => Navigator.pop(c, u),
                    ),
                ]),
              ),
            );
            if (uid != null) onPick(uid);
          },
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              gradient: Grad.sunset,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x55F25C2C), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: const Icon(Icons.edit_square, color: Colors.white),
          ),
        ),
      );
}

/// Sheet: your @username card (share it) and add someone by theirs.
Future<void> showAddFriend(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => const _AddFriendSheet(),
    );

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet();

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _ctl = TextEditingController();
  bool _busy = false;
  String? _msg;

  Future<void> _add() async {
    if (_ctl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final m = await social.addFriend(_ctl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = m;
    });
    if (m == 'انرسل الطلب' || m == 'صرتوا أصحاب') _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, code = social.mine?.code ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, MediaQuery.of(context).viewInsets.bottom + Gap.xl),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(Gap.l),
          decoration: BoxDecoration(gradient: Grad.night, borderRadius: BorderRadius.circular(Radii.card)),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(gradient: Grad.sunset, shape: BoxShape.circle),
              child: const UserAvatar(size: 72, shadow: false),
            ),
            const SizedBox(height: Gap.s),
            Text(settings.name.isEmpty ? 'عدّاء' : settings.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Text('@$code', textDirection: TextDirection.ltr, style: const TextStyle(color: Brand.sun, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: Gap.m),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const LaffaMark(width: 30),
              const SizedBox(width: Gap.s),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.navy),
                onPressed: () => Share.share('ضيفني في تطبيق لفّة وخلنا نجري سوا 🏃\nاسمي: @$code'),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('شارك اسمك'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: Gap.l),
        Text('أضف باسم المستخدم', style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
        const SizedBox(height: Gap.s),
        Row(children: [
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _ctl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  prefixText: '@',
                  hintText: 'username',
                  filled: true,
                  fillColor: p.sand2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          const SizedBox(width: Gap.s),
          SizedBox(
            height: 50,
            child: FilledButton(onPressed: _busy ? null : _add, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('أضف')),
          ),
        ]),
        if (_msg != null) ...[
          const SizedBox(height: Gap.s),
          Text(_msg!, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        ],
      ]),
    );
  }
}
