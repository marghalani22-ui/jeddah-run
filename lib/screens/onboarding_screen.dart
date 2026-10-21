import 'package:flutter/material.dart';

import '../services/location.dart';
import '../services/reminders.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/brand_mark.dart';
import '../widgets/gradient_button.dart';

/// First run: what Laffa is, name + weekly goal, then why we ask for
/// location and notifications before the system dialogs appear.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController(text: settings.name);
  int _i = 0;
  int _goal = settings.goalKm;

  void _next() {
    FocusScope.of(context).unfocus();
    if (_i == 3) {
      _finish();
      return;
    }
    _pages.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    if (_name.text.trim().isNotEmpty) await settings.setName(_name.text);
    await settings.setGoal(_goal);
    await settings.setOnboarded();
    reminders.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: _i == 0 ? Grad.night : null, color: p.sand),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, 0),
              child: Row(children: [
                for (var k = 0; k < 4; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsetsDirectional.only(end: 6),
                    width: k == _i ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: k == _i ? Brand.coral : (_i == 0 ? const Color(0x55FFFFFF) : p.edge),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const Spacer(),
                if (_i > 0 && _i < 3)
                  TextButton(onPressed: _next, child: Text('تخطّي', style: TextStyle(color: p.muted))),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (v) => setState(() => _i = v),
                children: [_welcome(), _about(p), _location(p), _notify(p)],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _page({required List<Widget> top, required Widget button, Widget? secondary}) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, Gap.xl),
        child: Column(children: [
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: top)),
          button,
          if (secondary != null) ...[const SizedBox(height: Gap.s), secondary],
        ]),
      );

  Widget _welcome() => _page(
        top: [
          const LaffaMark(width: 150),
          const SizedBox(height: Gap.l),
          const Text('لفّة', style: TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(height: Gap.s),
          const Text('كل لفّة تحسب', style: TextStyle(color: Color(0xFFCAD2E3), fontSize: 18)),
          const SizedBox(height: Gap.xxl),
          for (final (icon, t) in const [
            (Icons.directions_run_rounded, 'اجرِ وسجّل جولاتك بالـ GPS'),
            (Icons.toll_rounded, 'اجمع نقاط على كل كيلو وكل تحدي'),
            (Icons.storefront_rounded, 'استبدلها بخصومات عند متاجرك'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: Brand.sun),
                ),
                const SizedBox(width: Gap.m),
                Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
              ]),
            ),
        ],
        button: GradientButton(label: 'يلا نبدأ', icon: Icons.arrow_back_rounded, onPressed: _next),
      );

  Widget _about(Palette p) => _page(
        top: [
          Text('عرّفنا عليك', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: p.ink)),
          const SizedBox(height: Gap.xl),
          TextField(
            controller: _name,
            maxLength: 20,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.ink),
            decoration: InputDecoration(
              hintText: 'وش نناديك؟',
              counterText: '',
              filled: true,
              fillColor: p.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.edge)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.edge)),
            ),
          ),
          const SizedBox(height: Gap.xl),
          Text('كم كيلو تبي تجري بالأسبوع؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.ink)),
          const SizedBox(height: Gap.m),
          Wrap(spacing: Gap.s, runSpacing: Gap.s, alignment: WrapAlignment.center, children: [
            for (final (km, hint) in const [(10, 'بداية'), (20, 'متوسط'), (30, 'نشيط'), (50, 'محترف')])
              GestureDetector(
                onTap: () => setState(() => _goal = km),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: _goal == km ? Grad.sunset : null,
                    color: _goal == km ? null : p.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _goal == km ? Colors.transparent : p.edge),
                  ),
                  child: Column(children: [
                    Text('$km', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _goal == km ? Colors.white : p.ink)),
                    Text(hint, style: TextStyle(fontSize: 12, color: _goal == km ? Colors.white : p.muted)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: Gap.m),
          Text('تقدر تغيّره بعدين من ملفي', style: TextStyle(fontSize: 12.5, color: p.muted)),
        ],
        button: GradientButton(label: 'التالي', onPressed: _next),
      );

  Widget _primer(Palette p, {required IconData icon, required Gradient grad, required String title, required String body, required List<String> points}) => Column(children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(gradient: grad, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 58),
        ),
        const SizedBox(height: Gap.xl),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.ink)),
        const SizedBox(height: Gap.s),
        Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.muted, height: 1.6)),
        const SizedBox(height: Gap.l),
        for (final t in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: p.good, size: 20),
              const SizedBox(width: Gap.s),
              Expanded(child: Text(t, style: TextStyle(fontSize: 14.5, color: p.ink))),
            ]),
          ),
      ]);

  Widget _location(Palette p) => _page(
        top: [
          _primer(p,
              icon: Icons.location_on_rounded,
              grad: Grad.sea,
              title: 'نحتاج موقعك وقت الجري',
              body: 'عشان نرسم مسارك ونحسب المسافة والسرعة بدقة.',
              points: const ['نستخدمه بس وأنت مسجّل جولة', 'التتبع يكمّل لو قفلت الشاشة', 'مسارك ما يشوفه أحد إلا لو شاركته']),
        ],
        button: GradientButton(
          label: 'اسمح بالموقع',
          icon: Icons.my_location_rounded,
          gradient: Grad.sea,
          onPressed: () async {
            await ensureLocation(context);
            if (mounted) _next();
          },
        ),
        secondary: TextButton(onPressed: _next, child: Text('لاحقاً', style: TextStyle(color: p.muted))),
      );

  Widget _notify(Palette p) => _page(
        top: [
          Image.asset('assets/brand/rakood_happy.png', width: 130, height: 130),
          const SizedBox(height: Gap.l),
          Text('ركّوض يذكّرك', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.ink)),
          const SizedBox(height: Gap.s),
          Text('رسالة خفيفة بالوقت اللي تختاره، وتنبيه قبل ما تنقطع سلسلتك.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.muted, height: 1.6)),
          const SizedBox(height: Gap.l),
          Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.edge)),
            child: Row(children: [
              const LaffaMark(width: 34),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('لفّة', style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
                  Text('يلا يا بطل 🏃 الكورنيش ينتظرك', style: TextStyle(color: p.muted, fontSize: 13)),
                ]),
              ),
            ]),
          ),
        ],
        button: GradientButton(
          label: 'فعّل التذكيرات',
          icon: Icons.notifications_active_rounded,
          onPressed: () async {
            await reminders.askPermission();
            await _finish();
          },
        ),
        secondary: TextButton(
          onPressed: () async {
            await settings.setReminders(on: false, guard: false);
            await _finish();
          },
          child: Text('بدون تذكيرات', style: TextStyle(color: p.muted)),
        ),
      );
}
