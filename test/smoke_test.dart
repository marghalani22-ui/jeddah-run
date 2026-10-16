import 'package:flutter_test/flutter_test.dart';
import 'package:jeddah_run/state/settings.dart';

void main() {
  test('auto look resolves to a theme mode', () {
    final s = Settings();
    expect(s.look, Look.auto);
    expect(s.themeMode, isNotNull);
  });
}
