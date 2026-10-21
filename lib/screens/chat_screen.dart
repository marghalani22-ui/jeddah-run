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

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final prof = social.profiles[widget.otherUid];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
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
