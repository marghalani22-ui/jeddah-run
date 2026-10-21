import 'package:flutter/material.dart';

import 'runs.dart';
import 'settings.dart';

/// Rakood's mood, same rules as the home-screen widget.
enum Mood { hype, happy, waiting, worried, sad, sleepy }

(Mood, String) moodNow() {
  final now = DateTime.now();
  final last = runStore.runs.isEmpty ? null : runStore.runs.first.start;
  final days = last == null ? 99 : DateUtils.dateOnly(now).difference(DateUtils.dateOnly(last)).inDays;
  final s = runStore.streak;
  if (days == 0 && s >= 3) return (Mood.hype, 'إنت مرّة جامد! $s أيام ورا بعض');
  if (days == 0) return (Mood.happy, 'إيوه كدا! جولة اليوم تمّت');
  if (days == 1 && now.hour < 18) return (Mood.waiting, s > 0 ? 'جولة اليوم تكمّل سلسلة $s ${s == 1 ? 'يوم' : 'أيام'}' : 'جولة اليوم؟ أنا جاهز');
  if (days == 1) return (Mood.worried, s > 0 ? 'فينك؟ لا تقطع سلسلة $s أيام' : 'باقي وقت، يلا جولة خفيفة');
  if (days <= 3) return (Mood.sad, 'وحشتني الجولات… نرجع اليوم؟');
  if (last == null) return (Mood.waiting, 'جاهز لأول لفّة؟');
  return (Mood.sleepy, 'وحشتنا! جولة وحدة ونرجع');
}

String greeting() {
  final h = DateTime.now().hour;
  final name = settings.name.isEmpty ? '' : ' يا ${settings.name}';
  if (h < 12) return 'صباح الخير$name';
  if (h < 17) return 'هلا$name';
  return 'مساء الخير$name';
}

String moodAsset(Mood m) => 'assets/brand/rakood_${m.name}.png';
