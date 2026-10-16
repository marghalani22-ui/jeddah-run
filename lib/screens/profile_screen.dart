import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PageBody(children: [
      Text('ملفي', style: Theme.of(context).textTheme.headlineMedium),
      Column(children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: Brand.coral,
          child: Text(Demo.name.characters.first,
              style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: Gap.s),
        Text(Demo.code, style: Theme.of(context).textTheme.titleLarge),
        Text('المستوى ${Demo.level} · حي ${Demo.home}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gap.s),
        const SizedBox(width: 240, child: Bar(value: Demo.xp / Demo.xpMax, height: 6)),
        const SizedBox(height: 4),
        Text('${Demo.xpMax - Demo.xp} خبرة للمستوى ${Demo.level + 1}', style: Theme.of(context).textTheme.bodySmall),
      ]),
      const KpiRow(children: [
        Kpi(value: '1,184', unit: 'كم', label: 'المسافة'),
        Kpi(value: '196', label: 'جولة'),
        Kpi(value: '${Demo.bestStreak}', unit: 'يوم', label: 'أطول سلسلة'),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHead('المظهر'),
        ListenableBuilder(
          listenable: settings,
          builder: (context, _) => SegmentedButton<Look>(
            segments: const [
              ButtonSegment(value: Look.day, label: Text('نهاري'), icon: Icon(Icons.wb_sunny_outlined)),
              ButtonSegment(value: Look.night, label: Text('ليلي'), icon: Icon(Icons.nightlight_outlined)),
              ButtonSegment(value: Look.auto, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_outlined)),
            ],
            selected: {settings.look},
            showSelectedIcon: false,
            onSelectionChanged: (s) => settings.setLook(s.first),
          ),
        ),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('الحساب', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.muted)),
        const SizedBox(height: Gap.s),
        const Card(
          child: Column(children: [
            RowTile(icon: Icons.edit_outlined, label: 'الملف والهدف', value: '30 كم'),
            Divider(),
            RowTile(icon: Icons.watch_outlined, label: 'الأجهزة'),
            Divider(),
            RowTile(icon: Icons.star_outline, label: 'الاشتراك'),
          ]),
        ),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('التطبيق', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.muted)),
        const SizedBox(height: Gap.s),
        const Card(
          child: Column(children: [
            RowTile(icon: Icons.notifications_outlined, label: 'الإشعارات'),
            Divider(),
            RowTile(icon: Icons.widgets_outlined, label: 'الويدجت'),
            Divider(),
            RowTile(icon: Icons.lock_outline, label: 'الخصوصية'),
          ]),
        ),
      ]),
    ]);
  }
}
