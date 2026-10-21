import 'package:flutter/material.dart';

import '../services/social.dart';
import '../state/runs.dart';
import '../theme/tokens.dart';

/// One-to-one chat with a friend.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.otherUid});
  final String otherUid;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctl = TextEditingController();
  late final String _chatId = pairId(social.me!, widget.otherUid);
  late final Stream<List<Message>> _stream = social.messages(_chatId);

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

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final prof = social.profiles[widget.otherUid];
    return Scaffold(
      appBar: AppBar(
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
        title: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: Brand.coral, child: Text((prof?.name ?? '؟').characters.first, style: const TextStyle(color: Colors.white))),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prof?.name ?? '…', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (prof != null)
                Text('${fmtKm(prof.weekKm)} كم هالأسبوع${prof.streak > 0 ? ' · ${prof.streak} أيام متتالية' : ''}',
                    style: TextStyle(fontSize: 12, color: p.muted)),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
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
                    child: Text('ابدأ السوالف، أو اختر رسالة سريعة تحت', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.m),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final mine = m.from == social.me;
                  final newer = i > 0 ? msgs[i - 1] : null;
                  final tail = newer == null || newer.from != m.from;
                  return Align(
                    // RTL: my messages sit on the left (end), theirs on the right (start).
                    alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                    child: Container(
                      margin: EdgeInsets.only(top: 2, bottom: tail ? 8 : 2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .74),
                      decoration: BoxDecoration(
                        gradient: mine ? const LinearGradient(colors: [Color(0xFFF25C2C), Color(0xFFF77A2A)]) : null,
                        color: mine ? null : p.card,
                        border: mine ? null : Border.all(color: p.edge),
                        borderRadius: BorderRadiusDirectional.only(
                          topStart: const Radius.circular(18),
                          topEnd: const Radius.circular(18),
                          bottomStart: Radius.circular(mine ? 18 : (tail ? 4 : 18)),
                          bottomEnd: Radius.circular(mine ? (tail ? 4 : 18) : 18),
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                        Text(m.text, style: TextStyle(color: mine ? Colors.white : p.ink, fontSize: 15, height: 1.35)),
                        const SizedBox(height: 2),
                        Text(
                          '${m.at.hour % 12 == 0 ? 12 : m.at.hour % 12}:${m.at.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: mine ? Colors.white70 : p.muted, fontSize: 10.5),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.m),
            itemCount: _quick.length,
            separatorBuilder: (_, __) => const SizedBox(width: Gap.s),
            itemBuilder: (_, i) => ActionChip(label: Text(_quick[i]), onPressed: () => _send(_quick[i])),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.m),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالة',
                    counterText: '',
                    filled: true,
                    fillColor: p.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.edge)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.edge)),
                  ),
                ),
              ),
              const SizedBox(width: Gap.s),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Brand.coral, minimumSize: const Size(48, 48)),
                onPressed: () => _send(),
                icon: const Icon(Icons.send_rounded, color: Colors.white, textDirection: TextDirection.rtl),
                tooltip: 'إرسال',
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
