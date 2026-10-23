import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/tokens.dart';

/// How hot it feels, in running terms.
enum Heat { ok, warm, hot, danger }

class HourFeel {
  HourFeel(this.at, this.feels, this.humidity, this.uv);
  final DateTime at;
  final double feels, humidity, uv;
  Heat get heat => heatOf(feels);
}

Heat heatOf(double feels) => feels < 32
    ? Heat.ok
    : feels < 37
        ? Heat.warm
        : feels < 41
            ? Heat.hot
            : Heat.danger;

Color heatColor(Heat h) => switch (h) {
      Heat.ok => Brand.leaf,
      Heat.warm => const Color(0xFFE0A92E),
      Heat.hot => const Color(0xFFF07A2A),
      Heat.danger => const Color(0xFFD9354A),
    };

String heatName(Heat h) => switch (h) {
      Heat.ok => 'مناسب',
      Heat.warm => 'دافي',
      Heat.hot => 'حار',
      Heat.danger => 'خطر',
    };

String heatAdvice(Heat h) => switch (h) {
      Heat.ok => 'الجو مناسب للجري. خذ مويا معك.',
      Heat.warm => 'دافي شوي: خفّف السرعة، واشرب قبل وبعد، والبس فاتح.',
      Heat.hot => 'حار: جولة قصيرة بس، ووقف لو حسيت بدوخة أو صداع. الأفضل تأجّلها.',
      Heat.danger => 'خطر ضربة شمس. لا تجري برّا الحين، أجّلها للوقت المقترح أو جري داخلي.',
    };

/// "9م" / "5ص".
String hourLabel(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h${d.hour < 12 ? 'ص' : 'م'}';
}

/// Current "feels like" and the next 24 hours from Open-Meteo (free, no key).
class Weather extends ChangeNotifier {
  HourFeel? now;
  List<HourFeel> hours = [];
  DateTime? _fetched;
  bool _busy = false;

  /// Coolest hour in the next 24 h — the suggested time to run.
  HourFeel? get best => hours.isEmpty ? null : hours.reduce((a, b) => b.feels < a.feels ? b : a);

  Future<void> refresh({bool force = false}) async {
    if (_busy) return;
    if (!force && _fetched != null && DateTime.now().difference(_fetched!).inMinutes < 30) return;
    _busy = true;
    try {
      var lat = 21.54, lon = 39.17; // Jeddah until we know better
      try {
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) {
          lat = p.latitude;
          lon = p.longitude;
        }
      } catch (_) {}
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(3),
        'longitude': lon.toStringAsFixed(3),
        'current': 'apparent_temperature,relative_humidity_2m',
        'hourly': 'apparent_temperature,relative_humidity_2m,uv_index',
        'forecast_days': '2',
        'timezone': 'auto',
      });
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 10));
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) return;
      final j = jsonDecode(body) as Map<String, dynamic>;
      final c = j['current'] as Map<String, dynamic>;
      final h = j['hourly'] as Map<String, dynamic>;
      final t = (h['time'] as List).cast<String>();
      final f = (h['apparent_temperature'] as List);
      final hu = (h['relative_humidity_2m'] as List);
      final uv = (h['uv_index'] as List);
      final start = DateTime.now().subtract(const Duration(minutes: 30));
      hours = [
        for (var i = 0; i < t.length; i++)
          if (f[i] != null)
            HourFeel(DateTime.parse(t[i]), (f[i] as num).toDouble(), (hu[i] as num?)?.toDouble() ?? 0, (uv[i] as num?)?.toDouble() ?? 0),
      ].where((x) => x.at.isAfter(start) && x.at.isBefore(start.add(const Duration(hours: 24)))).toList();
      // UV for "now" comes from the current hour of the hourly series.
      now = HourFeel(DateTime.now(), (c['apparent_temperature'] as num).toDouble(), (c['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
          hours.isEmpty ? 0 : hours.first.uv);
      _fetched = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('weather: $e');
    } finally {
      _busy = false;
    }
  }
}

final weather = Weather();
