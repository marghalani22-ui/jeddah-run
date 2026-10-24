import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'runs.dart';

/// A personal record and the run (if any) that set it.
class Record {
  Record(this.def, this.value, this.run, this.at);
  final RecordDef def;
  final double value;
  final Run? run;
  final DateTime? at;

  String get display => def.format(value);
}

class RecordDef {
  const RecordDef(this.id, this.title, this.icon, this.group, this.hint, {this.lowerIsBetter = false, required this.format});
  final String id, title, group, hint;
  final IconData icon;
  final bool lowerIsBetter;
  final String Function(double v) format;
}

String _time(double s) => fmtDur(s.round());
String _km(double v) => '${fmtKm(v)} كم';

const recordDefs = [
  RecordDef('k1', 'أسرع كيلو', Icons.bolt_rounded, 'speed', 'اجرِ كيلو كامل', lowerIsBetter: true, format: _time),
  RecordDef('k5', 'أسرع 5 كم', Icons.looks_5_rounded, 'speed', 'اجرِ 5 كم بجولة وحدة', lowerIsBetter: true, format: _time),
  RecordDef('k10', 'أسرع 10 كم', Icons.military_tech_rounded, 'speed', 'اجرِ 10 كم بجولة وحدة', lowerIsBetter: true, format: _time),
  RecordDef('k21', 'أسرع نصف ماراثون', Icons.emoji_events_rounded, 'speed', 'اجرِ 21 كم بجولة وحدة', lowerIsBetter: true, format: _time),
  RecordDef('long', 'أطول جولة', Icons.route_rounded, 'distance', 'سجّل أول جولة', format: _km),
  RecordDef('time', 'أطول وقت جري', Icons.timer_rounded, 'distance', 'سجّل أول جولة', format: _time),
  RecordDef('day', 'أكثر يوم', Icons.today_rounded, 'distance', 'اجرِ في يوم', format: _km),
  RecordDef('week', 'أكثر أسبوع', Icons.date_range_rounded, 'distance', 'اجرِ في أسبوع', format: _km),
  RecordDef('streak', 'أطول سلسلة', Icons.local_fire_department_rounded, 'distance', 'اجرِ يومين ورا بعض', format: _days),
];

String _days(double v) => '${v.round()} يوم';

/// Fastest stretch of [n] consecutive full kilometres in a run, in seconds.
double? bestStretch(Run r, int n) {
  final s = r.splits;
  if (s.length < n) return null;
  var sum = 0, best = 1 << 30;
  for (var i = 0; i < s.length; i++) {
    sum += s[i];
    if (i >= n) sum -= s[i - n];
    if (i >= n - 1) best = math.min(best, sum);
  }
  return best.toDouble();
}

/// Computes every record from [runs]. Speed records only use valid runs
/// recorded in Laffa (with per-km splits); distance ones use all valid runs.
Map<String, Record> computeRecords(List<Run> runs) {
  final valid = runs.where((r) => r.flag == null).toList();
  final own = valid.where((r) => !r.imported).toList();
  final out = <String, Record>{};

  void best(RecordDef d, double? v, Run? r, DateTime? at) {
    if (v == null || v <= 0) return;
    final cur = out[d.id];
    if (cur == null || (d.lowerIsBetter ? v < cur.value : v > cur.value)) out[d.id] = Record(d, v, r, at ?? r?.start);
  }

  RecordDef def(String id) => recordDefs.firstWhere((d) => d.id == id);

  for (final r in own) {
    best(def('k1'), bestStretch(r, 1), r, null);
    best(def('k5'), bestStretch(r, 5), r, null);
    best(def('k10'), bestStretch(r, 10), r, null);
    best(def('k21'), bestStretch(r, 21), r, null);
  }
  for (final r in valid) {
    best(def('long'), r.km, r, null);
    best(def('time'), r.secs.toDouble(), r, null);
  }
  final byDay = <DateTime, double>{}, byWeek = <DateTime, double>{};
  for (final r in valid) {
    final d = DateUtils.dateOnly(r.start);
    byDay[d] = (byDay[d] ?? 0) + r.km;
    final w = RunStore.weekStart(r.start);
    byWeek[w] = (byWeek[w] ?? 0) + r.km;
  }
  byDay.forEach((d, km) => best(def('day'), km, null, d));
  byWeek.forEach((w, km) => best(def('week'), km, null, w));

  // Longest streak of consecutive days with a run.
  final days = byDay.keys.toList()..sort();
  var cur = 0, top = 0;
  DateTime? prev;
  DateTime? end;
  for (final d in days) {
    cur = (prev != null && d.difference(prev).inHours.round() <= 26) ? cur + 1 : 1;
    if (cur > top) {
      top = cur;
      end = d;
    }
    prev = d;
  }
  if (top >= 2) best(def('streak'), top.toDouble(), null, end);
  return out;
}

/// Records [run] just set, compared with all runs before it.
List<Record> newRecordsBy(Run run, List<Run> all) {
  final before = computeRecords(all.where((r) => !identical(r, run)).toList());
  final after = computeRecords(all);
  final out = <Record>[];
  for (final d in recordDefs) {
    final a = after[d.id], b = before[d.id];
    if (a == null || b == null) continue; // the first ever value isn't a "new record"
    if (a.value != b.value && (identical(a.run, run) || DateUtils.isSameDay(a.at ?? DateTime(0), run.start) || d.id == 'week' || d.id == 'streak')) {
      out.add(a);
    }
  }
  return out;
}
