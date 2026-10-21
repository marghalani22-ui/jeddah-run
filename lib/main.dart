import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/friends_screen.dart';
import 'screens/log_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shop_screen.dart';
import 'services/cloud.dart';
import 'services/health_sync.dart';
import 'services/reminders.dart';
import 'services/social.dart';
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
}

class JeddahRunApp extends StatelessWidget {
  const JeddahRunApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: phaseClock,
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
          home: const Shell(),
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
