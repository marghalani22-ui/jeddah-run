import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeddah_run/screens/share_screen.dart';
import 'package:jeddah_run/state/phase.dart';
import 'package:jeddah_run/state/runs.dart';
import 'package:jeddah_run/widgets/sky.dart';
import 'package:jeddah_run/theme/tokens.dart';

/// Renders every share template to PNG when PREVIEW_OUT is set (used by CI for visual review).
void main() {
  final out = Platform.environment['PREVIEW_OUT'];

  // A 6.2 km loop along the Jeddah corniche with a little GPS wobble.
  final rnd = math.Random(3);
  final path = <List<double>>[
    for (var i = 0; i <= 240; i++)
      () {
        final t = i / 240 * 2 * math.pi;
        return [21.585 + .012 * math.sin(t) + .0006 * math.sin(7 * t) + rnd.nextDouble() * .00008,
                39.105 + .007 * math.cos(t) * (1 + .25 * math.sin(2 * t))];
      }(),
  ];
  final run = Run(
    start: DateTime(2026, 10, 21, 6, 10),
    secs: 2245,
    meters: 6240,
    path: path,
    splits: const [372, 361, 358, 349, 366, 355],
  );

  testWidgets('render share templates', (tester) async {
    if (out == null) return;
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
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;

    final cases = <(String, Widget)>[
      ('1-photo-story', shareCardForTest(run, 0)),
      ('2-map-sunset', shareCardForTest(run, 1, palette: 0)),
      ('3-map-sea', shareCardForTest(run, 1, palette: 1)),
      ('4-map-night', shareCardForTest(run, 1, palette: 2)),
      ('5-sticker', ColoredBox(color: const Color(0xFF7A8499), child: shareCardForTest(run, 2))),
      ('6-minimal-sand', shareCardForTest(run, 3, palette: 3)),
      ('7-minimal-purple', shareCardForTest(run, 3, palette: 4)),
      for (final ph in Phase.values)
        ('sky-${ph.name}', ColoredBox(
          color: paletteOf(ph).sand,
          child: Align(alignment: Alignment.topCenter, child: SizedBox(height: 260, width: 360, child: CustomPaint(painter: SkyPainter(ph, .3, .4)))),
        )),
    ];
    for (final (name, card) in cases) {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Readex', extensions: const [Palette.day]),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(child: Center(child: RepaintBoundary(key: key, child: SizedBox(width: 360, height: 640, child: card)))),
        ),
      ));
      await tester.pumpAndSettle();
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1.5);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
