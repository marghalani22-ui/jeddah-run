import 'package:flutter_test/flutter_test.dart';
import 'package:jeddah_run/state/runs.dart';
import 'package:jeddah_run/state/settings.dart';

void main() {
  test('auto look resolves to a theme mode', () {
    expect(Settings().look, Look.auto);
  });

  test('formatting', () {
    expect(fmtDur(65), '01:05');
    expect(fmtDur(3725), '1:02:05');
    expect(fmtPace(362), '6:02');
    expect(fmtPace(0), '–:––');
  });

  test('run maths and json round-trip', () {
    final r = Run(start: DateTime(2026, 10, 17, 6), secs: 1800, meters: 5000, path: [
      [21.5, 39.1],
      [21.51, 39.11],
    ]);
    expect(r.points, 50);
    expect(r.secPerKm, 360);
    final back = Run.fromJson(r.toJson());
    expect(back.meters, 5000);
    expect(back.path.length, 2);
  });

  test('anti-cheat', () {
    expect(checkRun(meters: 5000, secs: 1800, rejected: 0, accepted: 200), isNull);
    expect(checkRun(meters: 5000, secs: 500, rejected: 0, accepted: 200), isNotNull);
    expect(checkRun(meters: 3000, secs: 1200, rejected: 80, accepted: 100), isNotNull);
    final flagged = Run(start: DateTime(2026), secs: 500, meters: 5000, path: const [], flag: 'x');
    expect(flagged.points, 0);
  });

  test('points: full km only', () {
    expect(kmPoints(0.6), 0);
    expect(kmPoints(1.99), 10);
    expect(kmPoints(31.4), 310);
  });
}
