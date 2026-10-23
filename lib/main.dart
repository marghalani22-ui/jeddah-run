import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/friends_screen.dart';
import 'screens/log_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/run_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/shop_screen.dart';
import 'services/cloud.dart';
import 'services/health_sync.dart';
import 'services/reminders.dart';
import 'services/run_draft.dart';
import 'services/social.dart';
import 'services/steps.dart';
import 'services/weather.dart';
import 'state/game.dart';
import 'state/phase.dart';
import 'state/runs.dart';
import 'state/settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Never block the first frame on storage: a failing plugin must not leave the splash screen up.
  try {
    await Future.wait([settings.load(), runStore.load(), game.load()]).timeout(const Duration(seconds: 4));
    await game.backfill();
  } catch (e) {
    debugPrint('startup load failed: $e');
  }
  phaseClock.start();
  runApp(const JeddahRunApp());
  unawaited(cloud.init());
  unawaited(reminders.init().then((_) => reminders.refresh()));
  unawaited(healthSync.init());
  unawaited(steps.init());
  unawaited(weather.refresh());
}

class JeddahRunApp extends StatelessWidget {
  const JeddahRunApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([phaseClock, settings]),
        builder: (context, _) => MaterialApp(
          title: 'لفّة',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(paletteOf(phaseClock.phase), brightnessOf(phaseClock.phase)),
          themeAnimationDuration: const Duration(milliseconds: 900),
          themeAnimationCurve: Curves.easeInOut,
          home: settings.onboarded || runStore.runs.isNotEmpty ? const Shell() : const OnboardingScreen(),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  /// A run that was going when the app was closed: continue, save or drop it.
  Future<void> _recover() async {
    final d = await RunDraft.load();
    if (d == null || !mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.directions_run_rounded, size: 40),
        title: const Text('عندك جولة ما خلصت'),
        content: Text('${fmtKm(d.meters / 1000)} كم في ${fmtDur(d.secs)}، بدأت ${fmtWhen(d.start)}.'
            '${d.resumable ? '' : '\nمرّ عليها وقت طويل، تقدر تحفظها بس.'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'drop'), child: const Text('احذفها')),
          if (d.meters >= 50) TextButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('احفظها')),
          if (d.resumable) FilledButton(onPressed: () => Navigator.pop(c, 'resume'), child: const Text('كمّلها')),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'resume':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RunScreen(resume: d), fullscreenDialog: true));
      case 'save':
        final c = await commitRun(d.toRun());
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SummaryScreen(run: c.run, fresh: true, rewards: c.rewards, levelUp: c.levelUp, goalReached: c.goalReached)));
      default:
        await RunDraft.clear();
    }
  }

  // The map tab stays alive; the other tabs are light and rebuild on demand.
  static const _pages = [MapScreen(), LogScreen(), FriendsScreen(), ShopScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, sizing: StackFit.expand, children: _pages),
        bottomNavigationBar: ListenableBuilder(
          listenable: social,
          builder: (context, _) => NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'الخريطة'),
            const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'سجلّي'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: social.unread + social.requestsIn > 0,
                label: Text('${social.unread + social.requestsIn}'),
                child: const Icon(Icons.group_outlined),
              ),
              selectedIcon: const Icon(Icons.group),
              label: 'الأصحاب',
            ),
            const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'المتجر'),
            const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'ملفي'),
          ],
        ),
        ),
      );
}
