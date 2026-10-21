import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/runs.dart';
import '../state/settings.dart';

/// Local reminders (no server needed) and the Rakood home-screen widget.
///
/// Every time the app opens or a run is saved we cancel and re-plan the next
/// 7 days: a daily nudge at the chosen time (skipped today if already ran),
/// a streak guard at 20:30 while a streak is alive, and comeback messages
/// after 3 and 7 quiet days.
class Reminders {
  final _n = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'التذكيرات',
    channelDescription: 'تذكير الجولة اليومية والسلسلة',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher_monochrome',
    color: Color(0xFFF25C2C),
  );

  static const _daily = [
    ('يلا يا بطل 🏃', 'الكورنيش ينتظرك، جولة خفيفة وترجع'),
    ('جولة اليوم؟', 'ربع ساعة بس وتحسب لك نقاط'),
    ('الجو حلو للجري', 'البس جزمتك وخلنا نلف لفّة'),
    ('ركّوض يسأل عنك 👀', 'وين جولة اليوم يا كابتن؟'),
    ('هدفك قريب', 'كل كيلو يقرّبك من هدف الأسبوع'),
    ('خلّها عادة', 'جولة اليوم تكمّل سلسلتك'),
    ('نقاطك تنتظرك 🪙', 'اجرِ واجمع، واستبدلها عند المتاجر'),
  ];

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
      await _n.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher_monochrome')));
      _ready = true;
    } catch (e) {
      debugPrint('reminders init: $e');
    }
  }

  Future<bool> askPermission() async {
    final a = _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await a?.requestNotificationsPermission() ?? true;
  }

  /// Re-plans the coming week and refreshes the widget.
  Future<void> refresh() async {
    await updateWidget();
    if (!_ready) return;
    try {
      await _n.cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
      final last = runStore.runs.isEmpty ? null : runStore.runs.first.start;
      final ranToday = last != null && DateUtils.isSameDay(last, DateTime.now());
      final streak = runStore.streak;
      final rnd = math.Random(today.day);
      var id = 100;

      Future<void> at(tz.TZDateTime when, String title, String body) async {
        if (!when.isAfter(now)) return;
        await _n.zonedSchedule(
          id++,
          title,
          body,
          when,
          const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      for (var d = 0; d < 7; d++) {
        final day = today.add(Duration(days: d));
        if (d == 0 && ranToday) continue;
        if (settings.remind) {
          final (t, b) = _daily[(rnd.nextInt(_daily.length) + d) % _daily.length];
          await at(tz.TZDateTime(tz.local, day.year, day.month, day.day, settings.remindHour, settings.remindMinute), t, b);
        }
        if (settings.streakGuard && streak > 0) {
          final s = streak + d; // the streak they'd be protecting that evening
          await at(tz.TZDateTime(tz.local, day.year, day.month, day.day, 20, 30), 'لا تقطعها! 🔥', 'سلسلة $s ${s == 1 ? 'يوم' : 'أيام'}، باقي لك كم ساعة على جولة اليوم');
        }
      }
      // Comeback nudges if the runner goes quiet.
      if (last != null && settings.remind) {
        final base = tz.TZDateTime(tz.local, last.year, last.month, last.day, settings.remindHour, settings.remindMinute);
        await at(base.add(const Duration(days: 3)), 'وحشتنا 🥲', 'ثلاث أيام بدون جولة… نرجع اليوم بلفّة خفيفة؟');
        await at(base.add(const Duration(days: 7)), 'ركّوض نايم 😴', 'أسبوع كامل! جولة وحدة وترجع الحماس');
      }
    } catch (e) {
      debugPrint('reminders refresh: $e');
    }
  }

  /// Shown right after a run when something is worth celebrating.
  Future<void> celebrate(Run run, {required double weekBefore}) async {
    if (!_ready) return;
    final goal = settings.goalKm.toDouble();
    String? title, body;
    if (weekBefore < goal && runStore.weekKm >= goal) {
      title = 'حققت هدف الأسبوع! 🎉';
      body = '${fmtKm(runStore.weekKm)} كم من $goal كم. إنت مرّة جامد';
    } else if (runStore.longest == run && runStore.runs.length > 1) {
      title = 'أطول جولة لك! 🏅';
      body = '${fmtKm(run.km)} كم، رقم قياسي جديد';
    } else if (runStore.streak >= 3 && runStore.streak % 7 == 0) {
      title = '${runStore.streak} أيام ورا بعض 🔥';
      body = 'سلسلة نار، كمّل';
    }
    if (title == null) return;
    try {
      await _n.show(1, title, body, const NotificationDetails(android: _channel));
    } catch (_) {}
  }

  Future<void> updateWidget() async {
    try {
      final last = runStore.runs.isEmpty ? 0 : runStore.runs.first.start.millisecondsSinceEpoch;
      await HomeWidget.saveWidgetData<int>('lastRunMs', last);
      await HomeWidget.saveWidgetData<int>('streak', runStore.streak);
      await HomeWidget.saveWidgetData<String>('weekKm', fmtKm(runStore.weekKm));
      await HomeWidget.saveWidgetData<int>('goalKm', settings.goalKm);
      await HomeWidget.updateWidget(androidName: 'RakoodWidget', qualifiedAndroidName: 'sa.jeddahrun.jeddah_run.RakoodWidget');
    } catch (e) {
      debugPrint('widget: $e');
    }
  }
}

final reminders = Reminders();
