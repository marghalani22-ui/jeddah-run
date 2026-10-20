import 'package:flutter/material.dart';

import '../services/cloud.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final ctl = TextEditingController(text: settings.name);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('اسمك'),
        content: TextField(controller: ctl, autofocus: true, maxLength: 20, decoration: const InputDecoration(hintText: 'اكتب اسمك')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (v != null) await settings.setName(v);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([runStore, settings]),
        builder: (context, _) {
          final p = context.pal;
          final name = settings.name.isEmpty ? 'عدّاء' : settings.name;
          final fast = runStore.fastest, long = runStore.longest;
          return PageBody(title: 'ملفي', children: [
            const _AccountCard(),
            Column(children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Brand.coral,
                child: Text(name.characters.first, style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: Gap.s),
              TextButton.icon(
                onPressed: () => _editName(context),
                icon: Icon(Icons.edit_outlined, size: 16, color: p.muted),
                label: Text(name, style: Theme.of(context).textTheme.titleLarge),
              ),
            ]),
            KpiCard(children: [
              Kpi(value: fmtKm(runStore.totalKm), unit: 'كم', label: 'المسافة'),
              Kpi(value: '${runStore.runs.length}', label: 'جولة'),
              Kpi(value: '${runStore.bestStreak}', unit: 'يوم', label: 'أطول سلسلة'),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionHead('أرقامك'),
              KpiCard(children: [
                Kpi(value: fast == null ? '–' : fmtPace(fast.secPerKm), unit: fast == null ? '' : '/كم', label: 'أسرع متوسط'),
                Kpi(value: long == null ? '–' : fmtKm(long.km), unit: long == null ? '' : 'كم', label: 'أطول جولة'),
              ]),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionHead('هدفك الأسبوعي'),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 10, label: Text('10 كم')),
                  ButtonSegment(value: 20, label: Text('20 كم')),
                  ButtonSegment(value: 30, label: Text('30 كم')),
                  ButtonSegment(value: 50, label: Text('50 كم')),
                ],
                selected: {settings.goalKm},
                showSelectedIcon: false,
                onSelectionChanged: (s) => settings.setGoal(s.first),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionHead('أثناء الجري'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  SwitchListTile(
                    value: settings.voice,
                    onChanged: settings.setVoice,
                    activeTrackColor: Brand.coral,
                    title: const Text('التنبيه الصوتي'),
                    subtitle: Text('يقولك الزمن والسرعة كل كيلو', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: settings.autoPause,
                    onChanged: settings.setAutoPause,
                    activeTrackColor: Brand.coral,
                    title: const Text('إيقاف تلقائي'),
                    subtitle: Text('يوقف الوقت لما توقف عند إشارة ويكمّل لما تتحرك', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ),
                ]),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionHead('المظهر'),
              SegmentedButton<Look>(
                segments: const [
                  ButtonSegment(value: Look.day, label: Text('نهاري'), icon: Icon(Icons.wb_sunny_outlined)),
                  ButtonSegment(value: Look.night, label: Text('ليلي'), icon: Icon(Icons.nightlight_outlined)),
                  ButtonSegment(value: Look.auto, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_outlined)),
                ],
                selected: {settings.look},
                showSelectedIcon: false,
                onSelectionChanged: (s) => settings.setLook(s.first),
              ),
            ]),
          ]);
        },
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  Future<void> _signIn(BuildContext context) async {
    final err = await cloud.signIn();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: cloud,
        builder: (context, _) {
          final p = context.pal, u = cloud.user;
          if (u == null) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.l),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Icon(Icons.cloud_off_outlined, color: p.muted),
                    const SizedBox(width: Gap.s),
                    Expanded(child: Text('جولاتك محفوظة على هذا الجوال بس', style: Theme.of(context).textTheme.titleMedium)),
                  ]),
                  const SizedBox(height: 4),
                  Text('سجّل دخول عشان تنحفظ جولاتك ونقاطك ولا تضيع لو غيّرت جوالك.', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: Gap.m),
                  FilledButton.icon(
                    onPressed: cloud.busy || !cloud.ready ? null : () => _signIn(context),
                    icon: cloud.busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login),
                    label: Text(cloud.ready ? 'الدخول بحساب قوقل' : 'الخدمة غير متاحة الحين'),
                  ),
                ]),
              ),
            );
          }
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: p.goodSoft, child: Icon(Icons.cloud_done_outlined, color: p.good)),
              title: Text(u.email ?? u.displayName ?? 'حسابك', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                cloud.busy ? 'نزامن…' : (cloud.error ?? 'جولاتك محفوظة في حسابك'),
                style: TextStyle(color: cloud.error != null ? p.bad : p.muted, fontSize: 12.5),
              ),
              trailing: TextButton(onPressed: cloud.signOut, child: const Text('خروج')),
            ),
          );
        },
      );
}
