import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Points rule: 10 points per full kilometre (subscribers ×2 later).
const pointsPerKm = 10;

class Run {
  Run({required this.start, required this.secs, required this.meters, required this.path});

  final DateTime start;
  final int secs;
  final double meters;

  /// [lat, lng] pairs.
  final List<List<double>> path;

  double get km => meters / 1000;
  double get secPerKm => meters > 0 ? secs / km : 0;
  int get points => (km * pointsPerKm).floor();

  Map<String, dynamic> toJson() => {
        's': start.millisecondsSinceEpoch,
        't': secs,
        'm': meters,
        'p': path.map((e) => [double.parse(e[0].toStringAsFixed(6)), double.parse(e[1].toStringAsFixed(6))]).toList(),
      };

  factory Run.fromJson(Map<String, dynamic> j) => Run(
        start: DateTime.fromMillisecondsSinceEpoch(j['s'] as int),
        secs: j['t'] as int,
        meters: (j['m'] as num).toDouble(),
        path: (j['p'] as List).map((e) => (e as List).map((v) => (v as num).toDouble()).toList()).toList(),
      );
}

class RunStore extends ChangeNotifier {
  final List<Run> runs = [];

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('runs');
    runs.clear();
    if (raw != null) {
      runs.addAll((jsonDecode(raw) as List).map((e) => Run.fromJson(e as Map<String, dynamic>)));
    }
    runs.sort((a, b) => b.start.compareTo(a.start));
    notifyListeners();
  }

  Future<void> add(Run r) async {
    runs.insert(0, r);
    notifyListeners();
    await _save();
  }

  Future<void> remove(Run r) async {
    runs.remove(r);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('runs', jsonEncode(runs.map((e) => e.toJson()).toList()));
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Saudi week starts on Sunday.
  static DateTime weekStart(DateTime d) => _day(d).subtract(Duration(days: d.weekday % 7));

  Iterable<Run> between(DateTime from, DateTime to) =>
      runs.where((r) => !r.start.isBefore(from) && r.start.isBefore(to));

  double kmIn(DateTime from, DateTime to) => between(from, to).fold(0.0, (a, r) => a + r.km);

  Iterable<Run> get thisWeek {
    final s = weekStart(DateTime.now());
    return between(s, s.add(const Duration(days: 7)));
  }

  double get weekKm => thisWeek.fold(0.0, (a, r) => a + r.km);

  /// Distance per week, oldest first, last entry = this week.
  List<double> lastWeeks(int n) {
    final s = weekStart(DateTime.now());
    return List.generate(n, (i) {
      final from = s.subtract(Duration(days: 7 * (n - 1 - i)));
      return kmIn(from, from.add(const Duration(days: 7)));
    });
  }

  double get totalKm => runs.fold(0.0, (a, r) => a + r.km);
  int get totalSecs => runs.fold(0, (a, r) => a + r.secs);
  int get points => runs.fold(0, (a, r) => a + r.points);

  Set<DateTime> get _days => runs.map((r) => _day(r.start)).toSet();

  /// Consecutive days with a run, ending today or yesterday.
  int get streak {
    final days = _days;
    var d = _day(DateTime.now());
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get bestStreak {
    final days = _days.toList()..sort();
    var best = 0, cur = 0;
    DateTime? prev;
    for (final d in days) {
      cur = (prev != null && d.difference(prev).inHours.round() <= 26) ? cur + 1 : 1;
      best = math.max(best, cur);
      prev = d;
    }
    return best;
  }

  Run? get longest => runs.isEmpty ? null : runs.reduce((a, b) => a.meters >= b.meters ? a : b);

  /// Fastest average pace among runs of at least 1 km.
  Run? get fastest {
    final ok = runs.where((r) => r.meters >= 1000).toList();
    return ok.isEmpty ? null : ok.reduce((a, b) => a.secPerKm <= b.secPerKm ? a : b);
  }
}

final runStore = RunStore();

String fmtDur(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

String fmtPace(double secPerKm) {
  if (secPerKm <= 0 || secPerKm.isInfinite || secPerKm > 3600) return '–:––';
  final s = secPerKm.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String fmtKm(double km) => km.toStringAsFixed(km >= 100 ? 0 : (km >= 10 ? 1 : 2));

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _dayNames = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String fmtWhen(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t = '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'ص' : 'م'}';
  if (diff == 0) return 'اليوم $t';
  if (diff == 1) return 'أمس $t';
  if (diff < 7) return '${_dayNames[d.weekday - 1]} $t';
  return '${d.day} ${_months[d.month - 1]}';
}

/// Time-of-day name for a run title.
String runTitle(DateTime d) {
  final h = d.hour;
  if (h < 5) return 'جولة الفجر';
  if (h < 11) return 'جولة الصباح';
  if (h < 15) return 'جولة الظهر';
  if (h < 18) return 'جولة العصر';
  if (h < 20) return 'جولة المغرب';
  return 'جولة الليل';
}
