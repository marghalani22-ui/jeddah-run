import 'package:flutter/material.dart';

import '../services/social.dart';
import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/friend_avatar.dart';
import 'friend_profile_screen.dart';

/// One-to-one chat with a friend.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.otherUid, this.debugMessages});
  final String otherUid;

  /// Preview tests feed messages directly instead of Firestore.
  final Stream<List<Message>>? debugMessages;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctl = TextEditingController();
  late final String _chatId = pairId(social.me!, widget.otherUid);
  late final Stream<List<Message>> _stream = widget.debugMessages ?? social.messages(_chatId);

  static const _quick = ['يلا نجري بكرة؟ 🏃', 'كم جريت اليوم؟', 'كفو عليك! 🔥', 'نلتقي الكورنيش الساعة 6'];

  @override
  void initState() {
    super.initState();
    social.markRead(_chatId);
  }

  @override
  void dispose() {
    social.markRead(_chatId);
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final t = text ?? _ctl.text;
    if (t.trim().isEmpty) return;
    _ctl.clear();
    try {
      await social.send(widget.otherUid, t);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما انرسلت الرسالة، تأكد إنكم أصحاب وإن النت شغال')));
    }
  }

  Future<void> _block(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('تحظر $name؟'),
        content: const Text('تنحذف الصداقة وتنقفل المحادثة، وما يقدر يرسل لك طلب مرة ثانية. تقدر تفك الحظر من ملفي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('حظر', style: TextStyle(color: context.pal.bad))),
        ],
      ),
    );
    if (ok != true) return;
    await social.block(widget.otherUid);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _report() async {
    const reasons = ['رسائل مزعجة', 'إساءة أو تنمّر', 'محتوى غير لائق', 'انتحال شخصية', 'شي ثاني'];
    String? reason;
    final note = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, MediaQuery.of(c).viewInsets.bottom + Gap.l),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('إبلاغ عن المحادثة', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: Gap.xs),
            Text('نراجع البلاغ بسرية، وما يوصله أي تنبيه.', style: TextStyle(color: c.pal.muted, fontSize: 13)),
            const SizedBox(height: Gap.m),
            Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
              for (final r in reasons) ChoiceChip(label: Text(r), selected: reason == r, onSelected: (_) => set(() => reason = r)),
            ]),
            const SizedBox(height: Gap.m),
            TextField(controller: note, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: 'تفاصيل (اختياري)', border: OutlineInputBorder())),
            const SizedBox(height: Gap.s),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: c.pal.bad),
              onPressed: reason == null ? null : () => Navigator.pop(c, true),
              child: const Text('أرسل البلاغ'),
            ),
          ]),
        ),
      ),
    );
    if (send != true || reason == null) return;
    final ok = await social.report(widget.otherUid, reason!, note: note.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'وصلنا البلاغ، شكراً لك' : 'ما انرسل البلاغ، جرّب مرة ثانية')));
  }

  String _clock(DateTime d) => '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')}${d.hour < 12 ? 'ص' : 'م'}';

  String _day(DateTime d) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(d, now)) return 'اليوم';
    if (DateUtils.isSameDay(d, now.subtract(const Duration(days: 1)))) return 'أمس';
    const names = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    if (now.difference(d).inDays < 7) return names[d.weekday - 1];
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final prof = social.profiles[widget.otherUid];
    final name = prof?.name ?? '…';
    return Scaffold(
      backgroundColor: p.sand,
      appBar: AppBar(
        backgroundColor: p.sand,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => v == 'report' ? _report() : _block(prof?.name ?? 'هذا الشخص'),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('إبلاغ'))),
              PopupMenuItem(value: 'block', child: ListTile(leading: Icon(Icons.block_rounded, color: p.bad), title: Text('حظر', style: TextStyle(color: p.bad)))),
            ],
          ),
        ],
        title: GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FriendProfileScreen(uid: widget.otherUid))),
          child: Row(children: [
          FriendAvatar(name: name, size: 38, ring: (prof?.weekKm ?? 0) > 0),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.ink)),
              if (prof != null)
                Text('${fmtKm(prof.weekKm)} كم هالأسبوع${prof.streak > 0 ? ' · ${prof.streak} 🔥' : ''}',
                    style: TextStyle(fontSize: 12, color: p.muted)),
            ]),
          ),
        ]),
        ),
      ),
      body: Column(children: [
        Divider(height: 1, color: p.edge),
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('تعذّر تحميل المحادثة', style: TextStyle(color: p.muted)));
              }
              final msgs = snap.data ?? const <Message>[];
              if (snap.hasData) WidgetsBinding.instance.addPostFrameCallback((_) => social.markRead(_chatId));
              if (msgs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      FriendAvatar(name: name, size: 84, ring: true),
                      const SizedBox(height: Gap.m),
                      Text('قل هلا لـ $name 👋', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink)),
                      const SizedBox(height: 4),
                      Text('أرسل رد سريع أو تحدّاه على جولة', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                    ]),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.m),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  // Newest first: msgs[i + 1] is the message just above this one.
                  final m = msgs[i];
                  final mine = m.from == social.me;
                  final above = i + 1 < msgs.length ? msgs[i + 1] : null;
                  final newDay = above == null || !DateUtils.isSameDay(above.at, m.at);
                  final newGroup = newDay || above.from != m.from || m.at.difference(above.at).inMinutes > 20;
                  final color = mine ? Brand.coral : Brand.sea;
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (newDay)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.m),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: p.sand2, borderRadius: BorderRadius.circular(12)),
                            child: Text(_day(m.at), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.muted)),
                          ),
                        ),
                      ),
                    if (newGroup)
                      Padding(
                        padding: EdgeInsets.only(top: newDay ? 0 : Gap.m, bottom: 3),
                        child: Row(children: [
                          Text(mine ? 'أنا' : name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
                          const SizedBox(width: 6),
                          Text(_clock(m.at), style: TextStyle(fontSize: 11, color: p.muted)),
                        ]),
                      ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsetsDirectional.only(start: 10, top: 2, bottom: 2),
                      decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: color, width: 2.5))),
                      child: _isEmoji(m.text)
                          ? Text(m.text, style: const TextStyle(fontSize: 40, height: 1.2))
                          : Text(m.text, style: TextStyle(color: p.ink, fontSize: 15.5, height: 1.4)),
                    ),
                  ]);
                },
              );
            },
          ),
        ),
        _Composer(ctl: _ctl, quick: _quick, onSend: _send),
      ]),
    );
  }

  static final _emojiOnly = RegExp(r'^(\p{Extended_Pictographic}|‍|️|\s){1,8}$', unicode: true);
  bool _isEmoji(String t) => t.trim().isNotEmpty && _emojiOnly.hasMatch(t.trim());
}

/// Bottom bar: one-tap reactions, quick replies, and a pill text field.
class _Composer extends StatefulWidget {
  const _Composer({required this.ctl, required this.quick, required this.onSend});
  final TextEditingController ctl;
  final List<String> quick;
  final Future<void> Function([String?]) onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _showQuick = false;
  static const _reactions = ['🔥', '👏', '🏃', '💪', '😂', '❤️'];

  @override
  void initState() {
    super.initState();
    widget.ctl.addListener(_changed);
  }

  @override
  void dispose() {
    widget.ctl.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final hasText = widget.ctl.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.edge))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: _showQuick
                ? SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, 0),
                      itemCount: widget.quick.length,
                      separatorBuilder: (_, __) => const SizedBox(width: Gap.s),
                      itemBuilder: (_, i) => ActionChip(
                        label: Text(widget.quick[i]),
                        onPressed: () {
                          widget.onSend(widget.quick[i]);
                          setState(() => _showQuick = false);
                        },
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, 0),
            child: Row(children: [
              for (final e in _reactions)
                Expanded(
                  child: InkResponse(
                    onTap: () => widget.onSend(e),
                    radius: 22,
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24))),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.m),
            child: Row(children: [
              InkResponse(
                onTap: () => setState(() => _showQuick = !_showQuick),
                radius: 24,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: _showQuick ? Brand.coral : p.sand2, shape: BoxShape.circle),
                  child: Icon(Icons.bolt_rounded, color: _showQuick ? Colors.white : p.ink),
                ),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: TextField(
                  controller: widget.ctl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  decoration: InputDecoration(
                    hintText: 'دردش',
                    counterText: '',
                    filled: true,
                    fillColor: p.sand2,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: hasText
                    ? Padding(
                        key: const ValueKey('send'),
                        padding: const EdgeInsetsDirectional.only(start: Gap.s),
                        child: InkResponse(
                          onTap: () => widget.onSend(),
                          radius: 24,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(gradient: Grad.sunset, shape: BoxShape.circle),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20, textDirection: TextDirection.rtl),
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('none')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
