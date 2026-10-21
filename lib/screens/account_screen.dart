import 'package:flutter/material.dart';

import '../services/cloud.dart';
import '../services/social.dart';
import '../theme/tokens.dart';
import '../widgets/brand_mark.dart';

/// Bottom of "ملفي": privacy, blocked runners, sign out and account deletion.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  Future<void> _delete(BuildContext context) async {
    final signedIn = cloud.user != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: c.pal.bad, size: 36),
        title: Text(signedIn ? 'تحذف حسابك نهائياً؟' : 'تمسح بياناتك من الجوال؟'),
        content: Text(signedIn
            ? 'تنحذف جولاتك ونقاطك وأوسمتك واسم المستخدم وأصحابك من السيرفر ومن هذا الجوال. ما نقدر نرجعها بعدين.'
            : 'تنمسح جولاتك ونقاطك وإعداداتك من هذا الجوال. ما نقدر نرجعها بعدين.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('احذف', style: TextStyle(color: c.pal.bad, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    final err = await cloud.deleteAccount();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([cloud, social]),
        builder: (context, _) {
          final p = context.pal;
          final signedIn = cloud.user != null;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.shield_outlined, color: p.ink),
                title: const Text('الخصوصية وشروط الاستخدام'),
                trailing: Icon(Icons.chevron_left_rounded, color: p.muted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              ),
              if (social.blocked.isNotEmpty) ...[
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.block_rounded, color: p.ink),
                  title: const Text('المحظورين'),
                  trailing: Text('${social.blocked.length}', style: TextStyle(color: p.muted)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _BlockedScreen())),
                ),
              ],
              if (signedIn) ...[
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: p.ink),
                  title: const Text('تسجيل الخروج'),
                  subtitle: Text('جولاتك تبقى على الجوال وفي حسابك', style: TextStyle(color: p.muted, fontSize: 12)),
                  onTap: cloud.signOut,
                ),
              ],
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: cloud.busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.delete_forever_outlined, color: p.bad),
                title: Text(signedIn ? 'حذف الحساب' : 'مسح بياناتي من الجوال', style: TextStyle(color: p.bad)),
                onTap: cloud.busy ? null : () => _delete(context),
              ),
            ]),
          );
        },
      );
}

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المحظورين')),
        body: ListenableBuilder(
          listenable: social,
          builder: (context, _) {
            final p = context.pal;
            final ids = social.blocked.toList();
            if (ids.isEmpty) return Center(child: Text('ما فيه أحد محظور', style: TextStyle(color: p.muted)));
            return ListView(children: [
              for (final id in ids)
                ListTile(
                  leading: CircleAvatar(backgroundColor: p.sand2, child: Icon(Icons.person_off_outlined, color: p.muted)),
                  title: Text(social.profiles[id]?.name ?? 'عدّاء'),
                  subtitle: social.profiles[id]?.code.isNotEmpty == true ? Text('@${social.profiles[id]!.code}') : null,
                  trailing: TextButton(onPressed: () => social.unblock(id), child: const Text('فك الحظر')),
                ),
            ]);
          },
        ),
      );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = [
    ('وش نجمع', [
      'موقعك أثناء تسجيل الجولة فقط، عشان نرسم المسار ونحسب المسافة والسرعة.',
      'جولاتك (المسار، المسافة، الزمن) ونقاطك وأوسمتك.',
      'لو سجّلت دخول بقوقل: بريدك واسمك من حساب قوقل.',
      'لو ربطت Health Connect: الجولات والخطوات اللي توافق عليها بس.',
      'اسم المستخدم وأرقام أسبوعك اللي يشوفها أصحابك، والرسائل بينك وبينهم.',
    ]),
    ('وش ما نسوي', [
      'ما نبيع بياناتك ولا نشاركها مع معلنين.',
      'ما نتتبع موقعك وأنت ما تجري.',
      'مسارك ما يشوفه أحد إلا لو أنت شاركته.',
    ]),
    ('وين تنحفظ', [
      'على جوالك، ولو سجّلت دخول في Firebase من قوقل (خوادم آمنة ومشفّرة).',
    ]),
    ('حقوقك', [
      'تقدر تعدّل اسمك وهدفك وصورتك من ملفي.',
      'تقدر تحذف أي جولة، أو تحذف حسابك كامل من ملفي ← حذف الحساب، وينحذف كل شي من السيرفر.',
      'تقدر تحظر أو تبلّغ عن أي شخص من المحادثة.',
    ]),
    ('شروط الاستخدام', [
      'النقاط للجري الحقيقي. الجولات اللي فيها غش (سيارة، دراجة، قفزات GPS) ما تاخذ نقاط، ويحق لنا نلغي نقاط أي حساب يتلاعب.',
      'النقاط ما لها قيمة نقدية وما تنحوّل لفلوس، وتنستبدل بس بعروض المتاجر الشريكة حسب شروط كل عرض.',
      'الاحترام في المحادثات إلزامي، والحسابات المسيئة تنقفل.',
      'انتبه لنفسك وأنت تجري: الطريق والحر والصحة مسؤوليتك، واستشر طبيبك لو عندك أي حالة.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية والشروط')),
      body: ListView(padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xxl), children: [
        Row(children: [
          const LaffaMark(width: 46),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Text('باختصار: بياناتك لك، نستخدمها عشان التطبيق يشتغل بس.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.ink, height: 1.5)),
          ),
        ]),
        const SizedBox(height: Gap.l),
        for (final (title, items) in _sections) ...[
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: Gap.s),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Brand.coral, shape: BoxShape.circle))),
                const SizedBox(width: Gap.s),
                Expanded(child: Text(t, style: TextStyle(color: p.ink, height: 1.6))),
              ]),
            ),
          const SizedBox(height: Gap.m),
        ],
      ]),
    );
  }
}
