import 'package:flutter/material.dart';

import '../state/game.dart';
import '../state/runs.dart';
import '../theme/tokens.dart';
import 'summary_screen.dart';

/// Where every point came from: runs, streaks, challenges, steps and badges.
class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _Item {
  _Item(this.at, this.kind, this.label, this.points, this.icon, {this.run});
  final DateTime at;
  final String kind, label;
  final int points;
  final IconData icon;
  final Run? run;
}

class _PointsScreenState extends State<PointsScreen> {
  String _filter = 'all';

  static const _filters = [
    ('all', 'الكل'),
    ('km', 'الجري'),
    ('bonus', 'السلسلة والتحديات'),
    ('steps', 'الخطوات'),
    ('badge', 'الأوسمة'),
  ];

  static const _kindIcon = {
    'streak': Icons.local_fire_department_rounded,
    'challenge': Icons.emoji_events_rounded,
    'weekly': Icons.event_available_rounded,
    'badge': Icons.military_tech_rounded,
    'steps': Icons.directions_walk_rounded,
  };

  static const _kindColor = {
    'km': Brand.coral,
    'streak': Color(0xFFFF7A1A),
    'challenge': Brand.sun,
    'weekly': Brand.sea,
    'badge': Brand.grape,
    'steps': Brand.leaf,
  };

  List<_Item> _items() {
    final out = <_Item>[
      for (final r in runStore.runs)
        if (r.points > 0) _Item(r.start, 'km', '${r.title} · ${fmtKm(r.km)} كم', r.points, Icons.directions_run_rounded, run: r),
      for (final e in game.ledger) _Item(e.at, e.kind, e.label, e.points, _kindIcon[e.kind] ?? Icons.star_rounded),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return out.where((i) {
      switch (_filter) {
        case 'km':
          return i.kind == 'km';
        case 'bonus':
          return i.kind == 'streak' || i.kind == 'challenge' || i.kind == 'weekly';
        case 'steps':
          return i.kind == 'steps';
        case 'badge':
          return i.kind == 'badge';
        default:
          return true;
      }
    }).toList();
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(d, now)) return 'اليوم';
    if (DateUtils.isSameDay(d, now.subtract(const Duration(days: 1)))) return 'أمس';
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final now = DateTime.now();
    final all = <_Item>[
      for (final r in runStore.runs)
        if (r.points > 0) _Item(r.start, 'km', '', r.points, Icons.directions_run),
      for (final e in game.ledger) _Item(e.at, e.kind, '', e.points, Icons.star),
    ];
    final month = all.where((i) => i.at.year == now.year && i.at.month == now.month).fold(0, (a, i) => a + i.points);
    final fromRuns = runStore.points, bonus = game.bonusPoints;
    final items = _items();

    return Scaffold(
      appBar: AppBar(title: const Text('سجل النقاط')),
      body: ListView(padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xxl), children: [
        Container(
          padding: const EdgeInsets.all(Gap.l),
          decoration: BoxDecoration(gradient: Grad.night, borderRadius: BorderRadius.circular(Radii.card)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(radius: 22, backgroundColor: Brand.sun, child: Icon(Icons.toll, color: Brand.navy)),
              const SizedBox(width: Gap.m),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('رصيدك', style: TextStyle(color: Color(0xFFA9B3C7), fontSize: 12.5)),
                Text('${game.balance}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1.1)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('هالشهر', style: TextStyle(color: Color(0xFFA9B3C7), fontSize: 12.5)),
                Text('+$month', style: const TextStyle(color: Brand.sun, fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
            ]),
            const SizedBox(height: Gap.m),
            // Split bar: distance vs bonuses.
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(children: [
                  if (fromRuns == 0 && bonus == 0) Expanded(child: Container(color: const Color(0x33FFFFFF))),
                  if (fromRuns > 0) Expanded(flex: fromRuns, child: Container(color: Brand.coral)),
                  if (bonus > 0) Expanded(flex: bonus, child: Container(color: Brand.sun)),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              const _Dot(Brand.coral),
              Text(' الجري $fromRuns', style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              const SizedBox(width: Gap.m),
              const _Dot(Brand.sun),
              Text(' المكافآت $bonus', style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ]),
          ]),
        ),
        const SizedBox(height: Gap.m),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: Gap.s),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(_filters[i].$2),
              selected: _filter == _filters[i].$1,
              onSelected: (_) => setState(() => _filter = _filters[i].$1),
            ),
          ),
        ),
        const SizedBox(height: Gap.s),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xxl),
            child: Text('ما فيه نقاط هنا للحين. أول كيلو كامل تجريه يبدأ رصيدك.', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          ),
        for (var i = 0; i < items.length; i++) ...[
          if (i == 0 || !DateUtils.isSameDay(items[i].at, items[i - 1].at))
            Padding(
              padding: const EdgeInsets.fromLTRB(4, Gap.l, 4, Gap.xs),
              child: Text(_dayLabel(items[i].at), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: p.muted)),
            ),
          _Row(item: items[i], color: _kindColor[items[i].kind] ?? Brand.coral),
        ],
        const SizedBox(height: Gap.l),
        Container(
          padding: const EdgeInsets.all(Gap.m),
          decoration: BoxDecoration(color: p.sunSoft, borderRadius: BorderRadius.circular(Radii.btn)),
          child: Text('10 نقاط لكل كيلو كامل (لين 300 باليوم)، وفوقها السلسلة والتحديات والخطوات والأوسمة. الصرف يظهر هنا أول ما تفتح عروض المتاجر.',
              style: TextStyle(color: p.goldInk, fontSize: 12.5, height: 1.6)),
        ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.c);
  final Color c;
  @override
  Widget build(BuildContext context) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.color});
  final _Item item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, i = item;
    final t = '${i.at.hour % 12 == 0 ? 12 : i.at.hour % 12}:${i.at.minute.toString().padLeft(2, '0')}${i.at.hour < 12 ? 'ص' : 'م'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: i.run == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(run: i.run!))),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
          child: Icon(i.icon, color: color, size: 22),
        ),
        title: Text(i.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: p.ink)),
        subtitle: Text(t, style: TextStyle(color: p.muted, fontSize: 12)),
        trailing: Text('+${i.points}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      ),
    );
  }
}
