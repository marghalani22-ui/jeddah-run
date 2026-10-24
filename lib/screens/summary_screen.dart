import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../state/game.dart';
import '../state/records.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/jmap.dart';
import '../widgets/celebration.dart';
import '../widgets/gradient_button.dart';
import '../widgets/pace_chart.dart';
import 'share_screen.dart';

/// Run summary: route on the real map, the numbers, and points earned.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.run, this.fresh = false, this.rewards = const [], this.levelUp, this.goalReached = false});
  final Run run;
  final bool fresh;
  final List<Reward> rewards;
  final int? levelUp;
  final bool goalReached;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late final List<Record> _newRecs = widget.fresh ? newRecordsBy(widget.run, runStore.runs) : const [];
  @override
  void initState() {
    super.initState();
    if (widget.fresh) WidgetsBinding.instance.addPostFrameCallback((_) => _party());
  }

  /// Biggest moment first, one after another.
  Future<void> _party() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final lv = widget.levelUp;
    if (lv != null && mounted) {
      await celebrate(context, icon: Icons.military_tech_rounded, title: 'المستوى $lv', subtitle: 'صرت «${levelTitle(lv)}»', color: Brand.grape);
    }
    for (final b in widget.rewards.where((r) => r.kind == 'badge')) {
      if (!mounted) return;
      await celebrate(context, icon: b.icon, title: 'وسام جديد!', subtitle: '${b.label.replaceFirst('وسام: ', '')} · +${b.points} نقطة', color: Brand.sun);
    }
    if (_newRecs.isNotEmpty && mounted) {
      await celebrate(context,
          icon: Icons.emoji_events_rounded,
          title: _newRecs.length == 1 ? 'رقم قياسي جديد!' : '${_newRecs.length} أرقام قياسية جديدة!',
          subtitle: _newRecs.map((r) => '${r.def.title}: ${r.display}').join('\n'),
          color: Brand.coral);
    }
    if (widget.goalReached && mounted) {
      await celebrate(context, icon: Icons.flag_rounded, title: 'هدف الأسبوع تم!', subtitle: '${fmtKm(runStore.weekKm)} كم من ${settings.goalKm} كم', color: Brand.leaf);
    }
  }

  MapLibreMapController? _map;
  late final List<LatLng> _pts = widget.run.path.map((e) => LatLng(e[0], e[1])).toList();

  Future<void> _drawRoute() async {
    final m = _map;
    if (m == null || _pts.length < 2) return;
    await m.addLine(LineOptions(geometry: _pts, lineColor: '#F25C2C', lineWidth: 5, lineJoin: 'round'));
    await m.addCircle(CircleOptions(geometry: _pts.first, circleRadius: 6, circleColor: '#2FB36C', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
    await m.addCircle(CircleOptions(geometry: _pts.last, circleRadius: 6, circleColor: '#F25C2C', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
    await m.moveCamera(CameraUpdate.newLatLngBounds(boundsOf(_pts), left: 40, top: 60, right: 40, bottom: 40));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تحذف الجولة؟'),
        content: const Text('بتنحذف من سجلّك ونقاطها بتنخصم.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('احذف', style: TextStyle(color: Brand.coral))),
        ],
      ),
    );
    if (ok != true) return;
    await runStore.remove(widget.run);
    if (mounted) Navigator.pop(context);
  }

  void _openShare() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShareScreen(run: widget.run)));

  Future<void> _rename() async {
    final ctl = TextEditingController(text: widget.run.name ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('اسم الجولة'),
        content: TextField(controller: ctl, autofocus: true, maxLength: 30, decoration: InputDecoration(hintText: runTitle(widget.run.start))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (v == null) return;
    await runStore.rename(widget.run, v);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.run, p = context.pal;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          IconButton(onPressed: _openShare, icon: const Icon(Icons.ios_share), tooltip: 'مشاركة'),
          IconButton(onPressed: _rename, icon: const Icon(Icons.edit_outlined), tooltip: 'تسمية الجولة'),
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'حذف'),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xxl), children: [
        Text(fmtWhen(r.start), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gap.m),
        if (r.imported) ...[
          Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(color: p.sunSoft, borderRadius: BorderRadius.circular(Radii.btn)),
            child: Text('جولة مستوردة من ${r.source}. تنحسب في المسافة والسلسلة والمستوى، بدون نقاط المتجر.',
                style: TextStyle(color: p.goldInk, fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: Gap.m),
        ],
        if (r.flag != null) ...[
          Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(color: p.badSoft, borderRadius: BorderRadius.circular(Radii.btn)),
            child: Row(children: [
              Icon(Icons.info_outline, color: p.bad),
              const SizedBox(width: Gap.s),
              Expanded(child: Text('ما انحسبت نقاط لهذي الجولة: ${r.flag}', style: TextStyle(color: p.bad, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: Gap.m),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card),
          child: SizedBox(
            height: 260,
            child: _pts.length < 2
                ? ColoredBox(color: p.sand2, child: const Center(child: Text('ما فيه مسار محفوظ')))
                : JMap(
                    target: _pts.first,
                    zoom: 15,
                    interactive: false,
                    onCreated: (c) => _map = c,
                    onStyleLoaded: _drawRoute,
                  ),
          ),
        ),
        const SizedBox(height: Gap.l),
        KpiCard(children: [
          Kpi(value: fmtKm(r.km), unit: 'كم', label: 'المسافة', big: true),
          Kpi(value: fmtDur(r.secs), label: 'الزمن', big: true),
        ]),
        const SizedBox(height: Gap.m),
        KpiCard(children: [
          Kpi(value: fmtPace(r.secPerKm), unit: '/كم', label: 'متوسط السرعة'),
          Kpi(value: '+${r.points}', label: 'نقاط'),
        ]),
        if (widget.rewards.isNotEmpty) ...[
          const SizedBox(height: Gap.xl),
          _Rewards(rewards: widget.rewards),
        ],
        if (_newRecs.isNotEmpty) ...[
          const SizedBox(height: Gap.m),
          _NewRecords(recs: _newRecs),
        ],
        if (!r.imported) ...[
          const SizedBox(height: Gap.xl),
          _Details(run: r, onChanged: () => setState(() {})),
        ],
        if (r.splits.isNotEmpty) ...[
          const SizedBox(height: Gap.xl),
          if (r.splits.length >= 2) ...[
            const SectionHead('منحنى السرعة', trailing: 'دقيقة/كم'),
            PaceChart(splits: r.splits),
            const SizedBox(height: Gap.l),
          ],
          const SectionHead('كل كيلو', trailing: 'الزمن'),
          _Splits(run: r),
        ],
        const SizedBox(height: Gap.xl),
        GradientButton(onPressed: _openShare, icon: Icons.ios_share, label: 'شارك جولتك'),
        if (widget.fresh) ...[
          const SizedBox(height: Gap.s),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ]),
    );
  }
}

/// One row per full kilometre, bar length relative to the slowest split.
class _Splits extends StatelessWidget {
  const _Splits({required this.run});
  final Run run;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, sp = run.splits;
    final slow = sp.reduce((a, b) => a > b ? a : b), fast = sp.reduce((a, b) => a < b ? a : b);
    final restM = run.meters - sp.length * 1000;
    final restS = run.secs - sp.fold(0, (a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(children: [
          for (var i = 0; i < sp.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600))),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: (sp[i] / slow).clamp(.15, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: sp[i] == fast ? Brand.coral : Brand.sea.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Gap.m),
                SizedBox(
                  width: 52,
                  child: Text(fmtPace(sp[i].toDouble()),
                      textAlign: TextAlign.end,
                      style: TextStyle(fontWeight: sp[i] == fast ? FontWeight.w700 : FontWeight.w500, color: p.ink)),
                ),
              ]),
            ),
          if (restM >= 50)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(child: Text('آخر ${restM.round()} م', style: TextStyle(color: p.muted, fontSize: 12.5))),
                Text(fmtPace(restS / (restM / 1000)), style: TextStyle(color: p.muted, fontSize: 12.5)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Rewards extends StatelessWidget {
  const _Rewards({required this.rewards});
  final List<Reward> rewards;

  @override
  Widget build(BuildContext context) {
    final total = rewards.fold(0, (a, r) => a + r.points);
    final (lv, into, need) = game.level;
    return Container(
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(gradient: Grad.night, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('مكسبك من الجولة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
          ShaderMask(
            shaderCallback: (r) => Grad.sunset.createShader(r),
            child: Text('+$total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26)),
          ),
        ]),
        const SizedBox(height: Gap.s),
        for (final r in rewards)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(r.icon, color: r.kind == 'badge' ? Brand.sun : const Color(0xFFA3AEC6), size: 20),
              const SizedBox(width: Gap.s),
              Expanded(child: Text(r.label, style: const TextStyle(color: Colors.white, fontSize: 14))),
              Text('+${r.points}', style: const TextStyle(color: Brand.sun, fontWeight: FontWeight.w700)),
            ]),
          ),
        const SizedBox(height: Gap.m),
        Text('المستوى $lv · ${levelTitle(lv)}', style: const TextStyle(color: Color(0xFFA3AEC6), fontSize: 12.5)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: into / need, minHeight: 7, color: Brand.sun, backgroundColor: const Color(0x33FFFFFF)),
        ),
      ]),
    );
  }
}

class _NewRecords extends StatelessWidget {
  const _NewRecords({required this.recs});
  final List<Record> recs;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.l),
        decoration: BoxDecoration(
          gradient: Grad.sunset,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.emoji_events_rounded, color: Colors.white),
            SizedBox(width: Gap.s),
            Text('رقم قياسي جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          const SizedBox(height: Gap.s),
          for (final r in recs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(r.def.icon, color: Colors.white, size: 18),
                const SizedBox(width: Gap.s),
                Expanded(child: Text(r.def.title, style: const TextStyle(color: Colors.white, fontSize: 14))),
                Text(r.display, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
            ),
        ]),
      );
}

/// "كيف كانت الجولة؟": one-tap feel, then kind and note in a sheet.
class _Details extends StatelessWidget {
  const _Details({required this.run, required this.onChanged});
  final Run run;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context) async {
    String? kind = run.kind;
    final note = TextEditingController(text: run.note ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, MediaQuery.of(c).viewInsets.bottom + Gap.l),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('نوع الجولة', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: Gap.s),
            Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
              for (final e in runKinds.entries)
                ChoiceChip(
                  avatar: Icon(e.value.$2, size: 18),
                  label: Text(e.value.$1),
                  selected: kind == e.key,
                  onSelected: (v) => set(() => kind = v ? e.key : null),
                ),
            ]),
            const SizedBox(height: Gap.l),
            Text('ملاحظة', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: Gap.s),
            TextField(
              controller: note,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'مثلاً: الجو رطب، الحذاء الجديد، جريت مع سلطان', border: OutlineInputBorder()),
            ),
            const SizedBox(height: Gap.s),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    await runStore.setDetails(run, kind: kind, feel: run.feel, note: note.text);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final k = runKinds[run.kind];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('كيف كانت الجولة؟', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Gap.m),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 0; i < feelFaces.length; i++)
              GestureDetector(
                onTap: () async {
                  await runStore.setDetails(run, kind: run.kind, feel: run.feel == i + 1 ? null : i + 1, note: run.note);
                  onChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: run.feel == i + 1 ? Brand.coral.withValues(alpha: .14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: run.feel == i + 1 ? Brand.coral : Colors.transparent, width: 1.5),
                  ),
                  child: Column(children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: run.feel == null || run.feel == i + 1 ? 1 : .4,
                      child: Text(feelFaces[i], style: const TextStyle(fontSize: 28)),
                    ),
                    Text(feelNames[i], style: TextStyle(fontSize: 10.5, color: run.feel == i + 1 ? Brand.coral : p.muted)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: Gap.s),
          Divider(height: 1, color: p.edge),
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => _edit(context),
            leading: Icon(k?.$2 ?? Icons.label_outline_rounded, color: k == null ? p.muted : Brand.coral),
            title: Text(k?.$1 ?? 'أضف نوع الجولة وملاحظة', style: TextStyle(fontWeight: FontWeight.w600, color: k == null ? p.muted : p.ink)),
            subtitle: run.note == null ? null : Text(run.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Icon(Icons.edit_outlined, color: p.muted, size: 20),
          ),
        ]),
      ),
    );
  }
}
