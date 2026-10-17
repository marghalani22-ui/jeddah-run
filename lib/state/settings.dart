import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Display mode: day, night, or auto (follows Jeddah daylight).
enum Look { day, night, auto }

class Settings extends ChangeNotifier {
  Look look = Look.auto;
  String name = '';
  int goalKm = 20;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString('look');
    look = Look.values.firstWhere((e) => e.name == v, orElse: () => Look.auto);
    name = sp.getString('name') ?? '';
    goalKm = sp.getInt('goalKm') ?? 20;
    notifyListeners();
  }

  Future<void> setLook(Look v) async {
    look = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('look', v.name);
  }

  Future<void> setName(String v) async {
    name = v.trim();
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('name', name);
  }

  Future<void> setGoal(int v) async {
    goalKm = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('goalKm', v);
  }

  /// Auto = light between roughly sunrise and sunset in Jeddah (UTC+3).
  ThemeMode get themeMode {
    switch (look) {
      case Look.day:
        return ThemeMode.light;
      case Look.night:
        return ThemeMode.dark;
      case Look.auto:
        final h = DateTime.now().toUtc().add(const Duration(hours: 3)).hour;
        return (h >= 6 && h < 18) ? ThemeMode.light : ThemeMode.dark;
    }
  }
}

final settings = Settings();
