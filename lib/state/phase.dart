import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/tokens.dart';
import 'settings.dart';

enum Phase { sunrise, day, sunset, night }

const phaseNames = {Phase.sunrise: 'الشروق', Phase.day: 'النهار', Phase.sunset: 'الغروب', Phase.night: 'الليل'};

Palette paletteOf(Phase p) => switch (p) {
      Phase.sunrise => Palette.sunrise,
      Phase.day => Palette.day,
      Phase.sunset => Palette.sunset,
      Phase.night => Palette.night,
    };

Brightness brightnessOf(Phase p) => (p == Phase.sunset || p == Phase.night) ? Brightness.dark : Brightness.light;

/// Sky colours top→bottom for the sky band.
List<Color> skyOf(Phase p) => switch (p) {
      Phase.sunrise => const [Color(0xFFF7A58A), Color(0xFFFFCFA6), Color(0xFFFFE9D2)],
      Phase.day => const [Color(0xFF6CC0E5), Color(0xFFADDDF0), Color(0xFFE6F4F8)],
      Phase.sunset => const [Color(0xFF3A2252), Color(0xFFC24E6A), Color(0xFFF59A4A)],
      Phase.night => const [Color(0xFF070C18), Color(0xFF111B33), Color(0xFF22335A)],
    };

/// Local sunrise and sunset (NOAA approximation, ±2 min).
(DateTime, DateTime) sunTimes(DateTime day, double lat, double lng) {
  final start = DateTime.utc(day.year, 1, 1);
  final n = DateTime.utc(day.year, day.month, day.day).difference(start).inDays + 1;
  final g = 2 * math.pi / 365 * (n - 1);
  final eq = 229.18 *
      (0.000075 + 0.001868 * math.cos(g) - 0.032077 * math.sin(g) - 0.014615 * math.cos(2 * g) - 0.040849 * math.sin(2 * g));
  final decl = 0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g) - 0.006758 * math.cos(2 * g) + 0.000907 * math.sin(2 * g) -
      0.002697 * math.cos(3 * g) + 0.00148 * math.sin(3 * g);
  final latR = lat * math.pi / 180;
  final cosH = math.cos(90.833 * math.pi / 180) / (math.cos(latR) * math.cos(decl)) - math.tan(latR) * math.tan(decl);
  final ha = math.acos(cosH.clamp(-1.0, 1.0)) * 180 / math.pi;
  final midnight = DateTime.utc(day.year, day.month, day.day);
  final rise = midnight.add(Duration(seconds: ((720 - 4 * (lng + ha) - eq) * 60).round())).toLocal();
  final set = midnight.add(Duration(seconds: ((720 - 4 * (lng - ha) - eq) * 60).round())).toLocal();
  return (rise, set);
}

/// Tracks the current phase from the real sun at the runner's location.
class PhaseClock extends ChangeNotifier {
  double lat = 21.5433, lng = 39.1728; // Jeddah until we know better
  Phase _auto = Phase.day;
  late DateTime sunrise, sunset;
  Timer? _t;

  Phase get phase => switch (settings.look) {
        Look.auto => _auto,
        Look.sunrise => Phase.sunrise,
        Look.day => Phase.day,
        Look.sunset => Phase.sunset,
        Look.night => Phase.night,
      };

  /// 0 at sunrise → 1 at sunset (outside daylight: <0 or >1).
  double get dayProgress {
    final now = DateTime.now();
    return now.difference(sunrise).inSeconds / sunset.difference(sunrise).inSeconds;
  }

  void start() {
    _compute();
    settings.addListener(notifyListeners);
    _t = Timer.periodic(const Duration(minutes: 1), (_) => _compute());
    _locate();
  }

  Future<void> _locate() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return;
      lat = p.latitude;
      lng = p.longitude;
      _compute();
    } catch (_) {}
  }

  void _compute() {
    final now = DateTime.now();
    final t = sunTimes(now, lat, lng);
    sunrise = t.$1;
    sunset = t.$2;
    final Phase p;
    if (now.isBefore(sunrise.subtract(const Duration(minutes: 40)))) {
      p = Phase.night;
    } else if (now.isBefore(sunrise.add(const Duration(minutes: 75)))) {
      p = Phase.sunrise;
    } else if (now.isBefore(sunset.subtract(const Duration(minutes: 60)))) {
      p = Phase.day;
    } else if (now.isBefore(sunset.add(const Duration(minutes: 40)))) {
      p = Phase.sunset;
    } else {
      p = Phase.night;
    }
    if (p != _auto) {
      _auto = p;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

final phaseClock = PhaseClock();
