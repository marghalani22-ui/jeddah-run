import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Display mode: auto follows real sunrise/sunset; or a fixed phase.
enum Look { auto, sunrise, day, sunset, night }

class Settings extends ChangeNotifier {
  Look look = Look.auto;
  String name = '';
  int goalKm = 20;
  bool voice = true, autoPause = true;
  bool remind = true, streakGuard = true;
  int remindHour = 18, remindMinute = 0;
  bool onboarded = false;
  String? photoPath;
  int stepGoal = 8000;
  bool batteryAsked = false;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString('look');
    look = Look.values.firstWhere((e) => e.name == v, orElse: () => Look.auto);
    name = sp.getString('name') ?? '';
    goalKm = sp.getInt('goalKm') ?? 20;
    voice = sp.getBool('voice') ?? true;
    autoPause = sp.getBool('autoPause') ?? true;
    remind = sp.getBool('remind') ?? true;
    streakGuard = sp.getBool('streakGuard') ?? true;
    remindHour = sp.getInt('remindHour') ?? 18;
    remindMinute = sp.getInt('remindMinute') ?? 0;
    onboarded = sp.getBool('onboarded') ?? false;
    photoPath = sp.getString('photo');
    stepGoal = sp.getInt('stepGoal') ?? 8000;
    batteryAsked = sp.getBool('batteryAsked') ?? false;
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

  Future<void> setVoice(bool v) async {
    voice = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('voice', v);
  }

  Future<void> setAutoPause(bool v) async {
    autoPause = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('autoPause', v);
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('onboarded', true);
  }

  Future<void> setPhoto(String? path) async {
    photoPath = path;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    if (path == null) {
      await sp.remove('photo');
    } else {
      await sp.setString('photo', path);
    }
  }

  Future<void> setReminders({bool? on, bool? guard, int? hour, int? minute}) async {
    remind = on ?? remind;
    streakGuard = guard ?? streakGuard;
    remindHour = hour ?? remindHour;
    remindMinute = minute ?? remindMinute;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('remind', remind);
    await sp.setBool('streakGuard', streakGuard);
    await sp.setInt('remindHour', remindHour);
    await sp.setInt('remindMinute', remindMinute);
  }

  Future<void> setStepGoal(int v) async {
    stepGoal = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('stepGoal', v);
  }

  Future<void> setBatteryAsked() async {
    batteryAsked = true;
    (await SharedPreferences.getInstance()).setBool('batteryAsked', true);
  }
}

final settings = Settings();
