import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/runs.dart';

enum HcStatus { unknown, notInstalled, needsUpdate, available }

/// Health Connect bridge: imports runs + steps from watches and other apps,
/// and writes Laffa runs back so they show up everywhere.
///
/// Imported runs count for distance, streaks and XP but earn no points
/// (they carry no GPS route we can check).
class HealthSync extends ChangeNotifier {
  final _h = Health();
  HcStatus status = HcStatus.unknown;
  bool connected = false, importOn = true, exportOn = true, busy = false;
  DateTime? lastSync;
  int? stepsToday;
  String? message;

  static const _types = [HealthDataType.WORKOUT, HealthDataType.STEPS, HealthDataType.DISTANCE_DELTA, HealthDataType.HEART_RATE];
  static const _perms = [HealthDataAccess.READ_WRITE, HealthDataAccess.READ, HealthDataAccess.READ, HealthDataAccess.READ];

  Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      connected = sp.getBool('hc') ?? false;
      importOn = sp.getBool('hcImport') ?? true;
      exportOn = sp.getBool('hcExport') ?? true;
      final ls = sp.getInt('hcLast');
      lastSync = ls == null ? null : DateTime.fromMillisecondsSinceEpoch(ls);
      await _h.configure();
      await refreshStatus();
      if (connected && status == HcStatus.available) await sync();
    } catch (e) {
      debugPrint('health init: $e');
    }
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    try {
      final s = await _h.getHealthConnectSdkStatus();
      status = switch (s) {
        HealthConnectSdkStatus.sdkAvailable => HcStatus.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => HcStatus.needsUpdate,
        _ => HcStatus.notInstalled,
      };
    } catch (_) {
      status = HcStatus.notInstalled;
    }
    notifyListeners();
  }

  Future<void> install() async {
    try {
      await _h.installHealthConnect();
    } catch (_) {}
  }

  Future<bool> connect() async {
    busy = true;
    message = null;
    notifyListeners();
    try {
      final ok = await _h.requestAuthorization(_types, permissions: _perms);
      connected = ok;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('hc', ok);
      if (ok) {
        await sync();
      } else {
        message = 'ما انعطت الصلاحيات. افتح Health Connect واسمح للفّة';
      }
      return ok;
    } catch (e) {
      message = 'تعذّر الربط: $e';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await _h.revokePermissions();
    } catch (_) {}
    connected = false;
    (await SharedPreferences.getInstance()).setBool('hc', false);
    notifyListeners();
  }

  Future<void> setImport(bool v) async {
    importOn = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('hcImport', v);
  }

  Future<void> setExport(bool v) async {
    exportOn = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('hcExport', v);
  }

  static bool _isRun(HealthWorkoutActivityType t) =>
      t == HealthWorkoutActivityType.RUNNING || t == HealthWorkoutActivityType.RUNNING_TREADMILL;

  /// Pulls the last 30 days of runs and today's steps.
  Future<void> sync() async {
    if (!connected) return;
    busy = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      stepsToday = await _h.getTotalStepsInInterval(start, now);

      if (importOn) {
        final pts = await _h.getHealthDataFromTypes(
          types: const [HealthDataType.WORKOUT],
          startTime: now.subtract(const Duration(days: 30)),
          endTime: now,
        );
        final known = {for (final r in runStore.runs) if (r.extId != null) r.extId!};
        // Our own runs exported earlier (same start minute) must not come back as imports.
        final mine = {for (final r in runStore.runs) if (!r.imported) r.start.millisecondsSinceEpoch ~/ 60000};
        final fresh = <Run>[];
        for (final p in pts) {
          final v = p.value;
          if (v is! WorkoutHealthValue || !_isRun(v.workoutActivityType)) continue;
          if (known.contains(p.uuid) || mine.contains(p.dateFrom.millisecondsSinceEpoch ~/ 60000)) continue;
          final meters = (v.totalDistance ?? 0).toDouble();
          final secs = p.dateTo.difference(p.dateFrom).inSeconds;
          if (meters < 200 || secs < 60) continue;
          final treadmill = v.workoutActivityType == HealthWorkoutActivityType.RUNNING_TREADMILL;
          fresh.add(Run(
            start: p.dateFrom,
            secs: secs,
            meters: meters,
            path: const [],
            name: treadmill ? 'جري على المشّاية' : null,
            source: p.sourceName.isEmpty ? 'Health Connect' : p.sourceName,
            extId: p.uuid,
          ));
        }
        if (fresh.isNotEmpty) await runStore.addAll(fresh);
        message = fresh.isEmpty ? 'كل جولاتك محدّثة' : 'انضافت ${fresh.length} ${fresh.length == 1 ? 'جولة' : 'جولات'}';
      }
      lastSync = now;
      (await SharedPreferences.getInstance()).setInt('hcLast', now.millisecondsSinceEpoch);
    } catch (e) {
      message = 'تعذّرت المزامنة';
      debugPrint('health sync: $e');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Writes a run recorded in Laffa to Health Connect.
  Future<void> export(Run r) async {
    if (!connected || !exportOn || r.imported) return;
    try {
      await _h.writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: r.start,
        end: r.start.add(Duration(seconds: r.secs)),
        totalDistance: r.meters.round(),
        totalDistanceUnit: HealthDataUnit.METER,
        title: r.title,
      );
    } catch (e) {
      debugPrint('health export: $e');
    }
  }
}

final healthSync = HealthSync();
