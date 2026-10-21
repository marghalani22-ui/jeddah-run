import 'package:flutter/material.dart';

import '../services/cloud.dart';
import '../services/reminders.dart';
import '../state/game.dart';
import '../state/phase.dart';
import '../widgets/sky.dart';
import '../widgets/game_widgets.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';

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
        listenable: Listenable.merge([runStore, settings, game]),
        builder: (context, _) {
          final p = context.pal;
          final name = settings.name.isEmpty ? 'عدّاء' : settings.name;
          final fast = runStore.fastest, long = runStore.longest;
          return PageBody(title: 'ملفي', children: [
            const _AccountCard(),
            Column(children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: Grad.sunset,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x40F25C2C), blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Text(name.characters.first, style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: Gap.s),
              TextButton.icon(
                onPressed: () => _editName(context),
                icon: Icon(Icons.edit_outlined, size: 16, color: p.muted),
                label: Text(name, style: Theme.of(context).textTheme.titleLarge),
              ),
            ]),
            const LevelCard(),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionHead('أوسمتي', trailing: '${game.badges.length} من ${badgeDefs.length}'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.s, Gap.l, Gap.s, Gap.s),
                  child: BadgeGrid(progressOf: (b) => b.progress(runStore)),
                ),
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
                onSelectionChanged: (s) => settings.setGoal(s.first).then((_) => reminders.refresh()),
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
              const SectionHead('التذكيرات'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  SwitchListTile(
                    value: settings.remind,
                    activeTrackColor: Brand.coral,
                    title: const Text('تذكير الجولة اليومي'),
                    subtitle: Text('رسالة خفيفة بالوقت اللي تختاره', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    onChanged: (v) async {
                      if (v) await reminders.askPermission();
                      await settings.setReminders(on: v);
                      reminders.refresh();
                    },
                  ),
                  if (settings.remind) ...[
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.schedule, color: p.ink),
                      title: const Text('وقت التذكير'),
                      trailing: Text(
                        TimeOfDay(hour: settings.remindHour, minute: settings.remindMinute).format(context),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.coral),
                      ),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: settings.remindHour, minute: settings.remindMinute),
                        );
                        if (t == null) return;
                        await settings.setReminders(hour: t.hour, minute: t.minute);
                        reminders.refresh();
                      },
                    ),
                  ],
                  const Divider(indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: settings.streakGuard,
                    activeTrackColor: Brand.coral,
                    title: const Text('حماية السلسلة'),
                    subtitle: Text('تنبيه الساعة 8:30 مساءً لو ما جريت وسلسلتك على وشك تنقطع', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    onChanged: (v) async {
                      await settings.setReminders(guard: v);
                      reminders.refresh();
                    },
                  ),
                ]),
              ),
              const SizedBox(height: Gap.s),
              Container(
                padding: const EdgeInsets.all(Gap.m),
                decoration: BoxDecoration(color: p.sunSoft, borderRadius: BorderRadius.circular(Radii.btn)),
                child: Row(children: [
                  Icon(Icons.widgets_outlined, color: p.goldInk),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Text('حط ويدجت ركّوض على شاشتك: اضغط مطوّلاً على الشاشة الرئيسية ← الأدوات (Widgets) ← لفّة',
                        style: TextStyle(color: p.goldInk, fontSize: 12.5, height: 1.5)),
                  ),
                ]),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionHead('المظهر'),
              const _LookPicker(),
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
                  GradientButton(
                    onPressed: !cloud.ready ? null : () => _signIn(context),
                    busy: cloud.busy,
                    icon: Icons.login,
                    label: cloud.ready ? 'الدخول بحساب قوقل' : 'الخدمة غير متاحة الحين',
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

class _LookPicker extends StatelessWidget {
  const _LookPicker();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    String t(DateTime d) => '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')}';
    Widget tile(Look look, Phase ph, String label) {
      final on = settings.look == look;
      return Expanded(
        child: GestureDetector(
          onTap: () => settings.setLook(look),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? Brand.coral : p.edge, width: on ? 2.5 : 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(children: [
                SizedBox(height: 54, child: CustomPaint(size: Size.infinite, painter: SkyPainter(ph, 0.3, 0.5))),
                Container(
                  width: double.infinity,
                  color: p.card,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: p.ink)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        onTap: () => settings.setLook(Look.auto),
        child: Container(
          padding: const EdgeInsets.all(Gap.m),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: settings.look == Look.auto ? Brand.coral : p.edge, width: settings.look == Look.auto ? 2.5 : 1),
          ),
          child: Row(children: [
            Icon(Icons.brightness_auto_rounded, color: settings.look == Look.auto ? Brand.coral : p.muted),
            const SizedBox(width: Gap.s),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تلقائي حسب الشمس', style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
                Text('الشروق ${t(phaseClock.sunrise)} ص · الغروب ${t(phaseClock.sunset)} م · الحين: ${phaseNames[phaseClock.phase]}',
                    style: TextStyle(fontSize: 12, color: p.muted)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: Gap.s),
      Row(children: [
        tile(Look.sunrise, Phase.sunrise, 'الشروق'),
        tile(Look.day, Phase.day, 'النهار'),
        tile(Look.sunset, Phase.sunset, 'الغروب'),
        tile(Look.night, Phase.night, 'الليل'),
      ]),
    ]);
  }
}
