import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../state/game.dart';
import '../state/settings.dart';
import 'health_sync.dart';
import 'weather.dart';

/// Step counter: the phone's own sensor (read by a background job every
/// ~15 min, see Steps.kt) plus Health Connect when linked; the higher wins.
class StepsService extends ChangeNotifier with WidgetsBindingObserver {
  static const _ch = MethodChannel('laffa/system');

  bool available = false, granted = false, ready = false;
  Map<String, int> days = {};

  /// Set when the daily mission was just completed; the map screen shows the celebration.
  Reward? justEarned;
  Timer? _poll;

  static String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get today => math.max(days[key(DateTime.now())] ?? 0, healthSync.stepsToday ?? 0);
  int get goal => settings.stepGoal;
  bool get on => (available && granted) || healthSync.stepsToday != null;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    healthSync.addListener(_check);
    try {
      available = await _ch.invokeMethod<bool>('stepsAvailable') ?? false;
      granted = await _ch.invokeMethod<bool>('stepsGranted') ?? false;
      if (available && granted) await _start();
    } catch (e) {
      debugPrint('steps init: $e');
    }
    ready = true;
    await refresh();
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  /// Asks for the "physical activity" permission and starts counting.
  Future<bool> enable() async {
    try {
      granted = await _ch.invokeMethod<bool>('stepsRequest') ?? false;
      if (granted) await _start();
    } catch (e) {
      debugPrint('steps enable: $e');
    }
    notifyListeners();
    await refresh();
    return granted;
  }

  Future<void> setGoal(int g) async {
    await settings.setStepGoal(g);
    try {
      await _ch.invokeMethod('stepsStart', {'goal': g});
    } catch (_) {}
    await _check();
  }

  Future<void> _start() => _ch.invokeMethod('stepsStart', {'goal': settings.stepGoal});

  Future<void> refresh() async {
    if (available && granted) {
      try {
        final raw = await _ch.invokeMethod<String>('stepsRead');
        if (raw != null) days = (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));
      } catch (e) {
        debugPrint('steps read: $e');
      }
    }
    await _check();
  }

  Future<void> _check() async {
    final r = await game.checkSteps(today, goal);
    if (r != null) justEarned = r;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      refresh();
      weather.refresh();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}

final steps = StepsService();
