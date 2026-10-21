import 'package:flutter/material.dart';

import '../services/health_sync.dart';
import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/gradient_button.dart';

/// "الأجهزة والتطبيقات": Health Connect today, more sources later.
class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    healthSync.refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the Play Store / Health Connect settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) healthSync.refreshStatus();
  }

  String _ago(DateTime d) {
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'الحين';
    if (m < 60) return 'قبل $m دقيقة';
    return fmtWhen(d);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(title: const Text('الأجهزة والتطبيقات')),
      body: ListenableBuilder(
        listenable: healthSync,
        builder: (context, _) {
          final h = healthSync;
          return ListView(padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xxl), children: [
            Text('اربط ساعتك وتطبيقاتك عشان تنسحب جولاتك وخطواتك تلقائياً، وتطلع جولات لفّة عندهم.',
                style: TextStyle(color: p.muted, height: 1.6)),
            const SizedBox(height: Gap.l),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.l),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(gradient: Grad.sea, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.favorite_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: Gap.m),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Health Connect', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.ink)),
                        Text('Samsung Health · Fitbit · Pixel Watch · Zepp · Strava وغيرها',
                            style: TextStyle(fontSize: 12, color: p.muted)),
                      ]),
                    ),
                    if (h.connected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: p.goodSoft, borderRadius: BorderRadius.circular(Radii.chip)),
                        child: Text('مربوط', style: TextStyle(color: p.good, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                  ]),
                  const SizedBox(height: Gap.l),
                  if (h.status == HcStatus.notInstalled || h.status == HcStatus.needsUpdate) ...[
                    Text(h.status == HcStatus.needsUpdate ? 'Health Connect يحتاج تحديث.' : 'Health Connect مو مثبت على جوالك.',
                        style: TextStyle(color: p.ink)),
                    const SizedBox(height: Gap.s),
                    GradientButton(label: h.status == HcStatus.needsUpdate ? 'حدّث Health Connect' : 'ثبّت Health Connect', icon: Icons.download_rounded, onPressed: h.install, gradient: Grad.sea),
                  ] else if (!h.connected) ...[
                    GradientButton(label: 'اربط Health Connect', icon: Icons.link_rounded, onPressed: h.connect, busy: h.busy, gradient: Grad.sea),
                  ] else ...[
                    Row(children: [
                      _Stat(label: 'خطوات اليوم', value: h.stepsToday == null ? '–' : '${h.stepsToday}'),
                      _Stat(label: 'آخر مزامنة', value: h.lastSync == null ? '–' : _ago(h.lastSync!)),
                    ]),
                    const SizedBox(height: Gap.s),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: h.importOn,
                      activeTrackColor: Brand.coral,
                      onChanged: h.setImport,
                      title: const Text('استيراد الجولات'),
                      subtitle: Text('من ساعتك وتطبيقاتك، آخر 30 يوم', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: h.exportOn,
                      activeTrackColor: Brand.coral,
                      onChanged: h.setExport,
                      title: const Text('تصدير جولات لفّة'),
                      subtitle: Text('عشان تطلع في Samsung Health وFitbit وغيرها', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ),
                    const SizedBox(height: Gap.s),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: h.busy ? null : h.sync,
                          icon: h.busy
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync_rounded),
                          label: const Text('زامن الحين'),
                        ),
                      ),
                      const SizedBox(width: Gap.s),
                      TextButton(onPressed: h.disconnect, child: Text('فك الربط', style: TextStyle(color: p.bad))),
                    ]),
                  ],
                  if (h.message != null) ...[
                    const SizedBox(height: Gap.s),
                    Text(h.message!, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: Gap.m),
            Container(
              padding: const EdgeInsets.all(Gap.m),
              decoration: BoxDecoration(color: p.sunSoft, borderRadius: BorderRadius.circular(Radii.btn)),
              child: Text(
                'الجولات المستوردة تنحسب في المسافة والسلسلة والمستوى، لكن بدون نقاط المتجر. النقاط للجولات اللي تسجّلها في لفّة بمسار GPS.',
                style: TextStyle(color: p.goldInk, fontSize: 13, height: 1.6),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Text('قريباً', style: TextStyle(fontWeight: FontWeight.w700, color: p.muted)),
            const SizedBox(height: Gap.s),
            const _Soon(icon: Icons.bolt_rounded, title: 'Strava', hint: 'سحب الجولات ورفع جولات لفّة'),
            const _Soon(icon: Icons.watch_rounded, title: 'Garmin', hint: 'بانتظار موافقة برنامج المطورين'),
            const _Soon(icon: Icons.apple, title: 'Apple Health', hint: 'مع نسخة الآيفون'),
            const _Soon(icon: Icons.watch_outlined, title: 'Huawei Health', hint: 'ربط منفصل'),
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.pal.ink)),
          Text(label, style: TextStyle(fontSize: 12, color: context.pal.muted)),
        ]),
      );
}

class _Soon extends StatelessWidget {
  const _Soon({required this.icon, required this.title, required this.hint});
  final IconData icon;
  final String title, hint;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: .6,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: context.pal.sand2, child: Icon(icon, color: context.pal.ink)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(hint),
        ),
      );
}
