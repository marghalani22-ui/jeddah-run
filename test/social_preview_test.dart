import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeddah_run/screens/chat_screen.dart';
import 'package:jeddah_run/screens/friend_profile_screen.dart';
import 'package:jeddah_run/screens/friends_screen.dart';
import 'package:jeddah_run/screens/points_screen.dart';
import 'package:jeddah_run/services/weather.dart';
import 'package:jeddah_run/state/game.dart';
import 'package:jeddah_run/state/runs.dart';
import 'package:jeddah_run/widgets/weather_widgets.dart';
import 'package:jeddah_run/services/social.dart';
import 'package:jeddah_run/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the friends list and a chat with fake data (no Firebase) when PREVIEW_OUT is set.
void main() {
  final out = Platform.environment['PREVIEW_OUT'];

  testWidgets('render social screens', (tester) async {
    if (out == null) return;
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      Future<void> load(String family, String file) async {
        final f = File(file);
        if (!f.existsSync()) return;
        final l = FontLoader(family)..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
        await l.load();
      }

      await load('Readex', 'test/fonts/Readex.ttf');
      await load('MaterialIcons', '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    });
    Directory(out).createSync(recursive: true);

    final now = DateTime.now();
    Timestamp ago(int m) => Timestamp.fromDate(now.subtract(Duration(minutes: m)));
    social.debugMe = 'me';
    social.mine = Profile('me', {'name': 'حسان', 'code': 'hassan', 'weekKm': 12.4, 'streak': 4});
    final people = {
      'a': {'name': 'سلطان', 'code': 'sultan', 'weekKm': 18.2, 'streak': 9},
      'b': {'name': 'ريم', 'code': 'reem_runs', 'weekKm': 9.6, 'streak': 3},
      'c': {'name': 'فيصل', 'code': 'faisal', 'weekKm': 21.0, 'streak': 12, 'totalKm': 312.4, 'runs': 58, 'level': 9, 'bestStreak': 21, 'longestKm': 15.2, 'badges': ['first', 'k5', 'k10']},
      'd': {'name': 'نورة', 'code': 'noura', 'weekKm': 0, 'streak': 0},
      'e': {'name': 'ماجد', 'code': 'majed99', 'weekKm': 5, 'streak': 1},
    };
    people.forEach((k, v) => social.profiles[k] = Profile(k, v));
    social.friendships = [
      for (final k in ['a', 'b', 'c', 'd']) Friendship(pairId('me', k), {'members': ['me', k], 'status': 'accepted', 'requester': k}, 'me'),
      Friendship(pairId('me', 'e'), {'members': ['me', 'e'], 'status': 'pending', 'requester': 'e'}, 'me'),
    ];
    social.chats = {
      pairId('me', 'a'): ChatInfo(pairId('me', 'a'), {'lastText': 'يلا بكرة؟', 'lastFrom': 'a', 'lastAt': ago(4)}),
      pairId('me', 'b'): ChatInfo(pairId('me', 'b'), {'lastText': 'كفو', 'lastFrom': 'me', 'lastAt': ago(95)}),
      pairId('me', 'c'): ChatInfo(pairId('me', 'c'), {'lastText': 'تم', 'lastFrom': 'c', 'lastAt': ago(60 * 26)}),
    };
    await tester.runAsync(() => social.markRead(pairId('me', 'c')));

    final msgs = <Message>[
      for (final (from, text, m) in [
        ('a', 'نلتقي الكورنيش الساعة 6؟', 3),
        ('a', '🔥', 4),
        ('me', 'أكيد، بس خلنا نسوي 8 كيلو هالمرة', 6),
        ('me', 'أمس سويت 6.2 بسرعة 5:58 😅', 7),
        ('a', 'كفو عليك! شفت جولتك أمس', 9),
        ('a', 'وش رأيك نتحدى فيصل هالأسبوع؟', 60 * 24 + 30),
        ('me', 'يلا 💪', 60 * 24 + 25),
      ])
        Message('$m', {'from': from, 'text': text, 'at': ago(m)}),
    ];

    // Points history and weather data.
    final rp = <List<double>>[[21.56, 39.13], [21.57, 39.13]];
    runStore.runs.addAll([
      Run(start: now.subtract(const Duration(hours: 2)), secs: 1900, meters: 5320, path: rp, splits: const [360, 355, 350, 362, 349]),
      Run(start: now.subtract(const Duration(days: 1, hours: 3)), secs: 2600, meters: 7100, path: rp),
    ]);
    game.ledger.addAll([
      LedgerEntry({'id': 's1', 'k': 'streak', 'l': 'مكافأة السلسلة · يوم 4', 'p': 20, 't': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch}),
      LedgerEntry({'id': 'c1', 'k': 'challenge', 'l': 'تحدي: 5 كم بجولة وحدة', 'p': 25, 't': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch}),
      LedgerEntry({'id': 'st', 'k': 'steps', 'l': 'مهمة الخطوات · 8,000 خطوة', 'p': 20, 't': now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch}),
      LedgerEntry({'id': 'b1', 'k': 'badge', 'l': 'وسام: أول 5 كم', 'p': 40, 't': now.subtract(const Duration(days: 1, hours: 3)).millisecondsSinceEpoch}),
    ]);
    weather.now = HourFeel(now, 38.4, 62, 8);
    weather.hours = [for (var i = 0; i < 18; i++) HourFeel(now.add(Duration(hours: i)), 38.4 - 9 * (i / 9 - (i > 9 ? (i - 9) / 4.5 : 0)), 60, 0)];

    final themes = {'day': (Palette.day, Brightness.light), 'night': (Palette.night, Brightness.dark)};
    for (final MapEntry(key: tn, value: (pal, br)) in themes.entries) {
      ThemeData theme() => ThemeData(
            useMaterial3: true,
            brightness: br,
            fontFamily: 'Readex',
            colorScheme: ColorScheme.fromSeed(seedColor: Brand.coral, brightness: br, primary: Brand.coral, surface: pal.card),
            scaffoldBackgroundColor: pal.sand,
            dividerTheme: DividerThemeData(color: pal.edge),
            extensions: [pal],
          );
      final cases = <(String, Widget)>[
        ('friends-$tn', const Scaffold(body: FriendsList())),
        ('chat-$tn', ChatScreen(otherUid: 'a', debugMessages: Stream.value(msgs))),
        ('friend-$tn', const FriendProfileScreen(uid: 'c')),
        ('points-$tn', const PointsScreen()),
        ('weather-$tn', const Scaffold(body: SafeArea(child: Column(children: [Padding(padding: EdgeInsets.all(12), child: WeatherPill()), Spacer(), Card(child: WeatherSheet())])))),
      ];
      for (final (name, screen) in cases) {
        final key = GlobalKey();
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: theme(),
            home: screen,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 2);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
        });
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
