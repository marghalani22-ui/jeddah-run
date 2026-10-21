import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'runs.dart';

/// Game layer on top of runs: streak bonus, daily/weekly challenges, badges, XP and levels.
///
/// Economy (points spendable in the shop):
///   • distance: 10 per full km, max 300 a day (in runs.dart)
///   • streak bonus: first run of ≥1 km each day, 5 × streak day, max 50
///   • daily challenges: 15–30 each, 3 a day
///   • weekly challenge: 60
///   • badges: one-off 25–100
/// XP (for levels only) = 10 per km with no cap + the same bonuses.

class Reward {
  Reward(this.kind, this.label, this.points, {this.xp, this.icon = Icons.star_rounded});
  final String kind, label;
  final int points;
  final int? xp;
  final IconData icon;

  Map<String, dynamic> toJson(String id, DateTime at) => {'id': id, 'k': kind, 'l': label, 'p': points, 'x': xp ?? points, 't': at.millisecondsSinceEpoch};
}

class LedgerEntry {
  LedgerEntry(Map<String, dynamic> j)
      : id = j['id'] as String,
        kind = j['k'] as String,
        label = j['l'] as String,
        points = j['p'] as int,
        xp = j['x'] as int? ?? j['p'] as int,
        at = DateTime.fromMillisecondsSinceEpoch(j['t'] as int);
  final String id, kind, label;
  final int points, xp;
  final DateTime at;
}

// ───────────────────────── challenges ─────────────────────────

class Challenge {
  const Challenge(this.id, this.title, this.points, this.icon, this.progress, {this.minLevel = 1});
  final String id, title;
  final int points, minLevel;
  final IconData icon;

  /// 0..1 progress from today's runs.
  final double Function(List<Run> today) progress;
}

bool _early(Run r) => r.start.hour < 7 && r.km >= 1;

final List<Challenge> _daily = [
  Challenge('d3', 'اجرِ 3 كم في جولة وحدة', 20, Icons.straighten, (t) => t.isEmpty ? 0 : t.map((r) => r.km / 3).reduce(math.max)),
  Challenge('d5', 'اجرِ 5 كم في جولة وحدة', 30, Icons.straighten, (t) => t.isEmpty ? 0 : t.map((r) => r.km / 5).reduce(math.max), minLevel: 4),
  Challenge('early', 'جولة قبل 7 الصبح (1 كم+)', 20, Icons.wb_twilight, (t) => t.any(_early) ? 1 : 0),
  Challenge('fast', 'كيلو أسرع من 6:30', 15, Icons.bolt, (t) => t.any((r) => r.splits.any((s) => s <= 390)) ? 1 : 0),
  Challenge('fast2', 'كيلو أسرع من 5:30', 25, Icons.bolt, (t) => t.any((r) => r.splits.any((s) => s <= 330)) ? 1 : 0, minLevel: 6),
  Challenge('dur20', 'اجرِ 20 دقيقة متواصلة', 15, Icons.timer_outlined, (t) => t.isEmpty ? 0 : t.map((r) => r.secs / 1200).reduce(math.max)),
  Challenge('dur40', 'اجرِ 40 دقيقة متواصلة', 25, Icons.timer_outlined, (t) => t.isEmpty ? 0 : t.map((r) => r.secs / 2400).reduce(math.max), minLevel: 5),
  Challenge('twice', 'جولتين اليوم (كل وحدة 1 كم+)', 20, Icons.repeat, (t) => t.where((r) => r.km >= 1).length / 2),
];

// ───────────────────────── badges ─────────────────────────

class BadgeDef {
  const BadgeDef(this.id, this.title, this.hint, this.icon, this.color, this.points, this.progress);
  final String id, title, hint;
  final IconData icon;
  final Color color;
  final int points;

  /// 0..1, 1 = unlocked.
  final double Function(RunStore s) progress;
}

double _ratio(num v, num of) => (v / of).clamp(0, 1).toDouble();
double _maxRun(RunStore s) => s.runs.isEmpty ? 0 : s.runs.map((r) => r.km).reduce(math.max);

int _goalWeeks(RunStore s, int goal) {
  final now = RunStore.weekStart(DateTime.now());
  var n = 0;
  for (var i = 1; i <= 52; i++) {
    final from = now.subtract(Duration(days: 7 * i));
    if (s.kmIn(from, from.add(const Duration(days: 7))) >= goal) n++;
  }
  return n;
}

const _coral = Color(0xFFF25C2C), _sun = Color(0xFFE0A92E), _sea = Color(0xFF0B6E8A), _grape = Color(0xFF5B3FD9), _leaf = Color(0xFF2FB36C), _navy = Color(0xFF22335A);

final List<BadgeDef> badgeDefs = [
  BadgeDef('first', 'أول لفّة', 'سجّل أول جولة', Icons.flag_rounded, _coral, 25, (s) => _ratio(s.runs.length, 1)),
  BadgeDef('k5', 'أول 5 كم', 'جولة وحدة 5 كم', Icons.looks_5_rounded, _coral, 40, (s) => _ratio(_maxRun(s), 5)),
  BadgeDef('k10', 'العشرة', 'جولة وحدة 10 كم', Icons.military_tech_rounded, _sun, 60, (s) => _ratio(_maxRun(s), 10)),
  BadgeDef('half', 'نصف ماراثون', 'جولة وحدة 21.1 كم', Icons.emoji_events_rounded, _grape, 100, (s) => _ratio(_maxRun(s), 21.1)),
  BadgeDef('t50', '50 كم', 'إجمالي 50 كم', Icons.route_rounded, _sea, 40, (s) => _ratio(s.totalKm, 50)),
  BadgeDef('t100', 'المئوية', 'إجمالي 100 كم', Icons.route_rounded, _sea, 60, (s) => _ratio(s.totalKm, 100)),
  BadgeDef('t500', 'خمسمية', 'إجمالي 500 كم', Icons.public_rounded, _grape, 100, (s) => _ratio(s.totalKm, 500)),
  BadgeDef('s7', 'أسبوع نار', 'سلسلة 7 أيام', Icons.local_fire_department_rounded, _coral, 50, (s) => _ratio(s.bestStreak, 7)),
  BadgeDef('s30', 'شهر كامل', 'سلسلة 30 يوم', Icons.local_fire_department_rounded, _grape, 100, (s) => _ratio(s.bestStreak, 30)),
  BadgeDef('dawn', 'طائر الفجر', 'جولة 1 كم+ قبل 6 الصبح', Icons.wb_twilight_rounded, _sun, 30, (s) => s.runs.any((r) => r.start.hour < 6 && r.km >= 1) ? 1 : 0),
  BadgeDef('night', 'عدّاء الليل', 'جولة 1 كم+ بعد 10 بالليل', Icons.nightlight_round, _navy, 30, (s) => s.runs.any((r) => r.start.hour >= 22 && r.km >= 1) ? 1 : 0),
  BadgeDef('friday', 'جمعة رياضية', 'جولة 3 كم+ يوم الجمعة', Icons.calendar_month_rounded, _leaf, 25, (s) => s.runs.any((r) => r.start.weekday == DateTime.friday && r.km >= 3) ? 1 : 0),
  BadgeDef('sub5', 'الصاروخ', 'كيلو أسرع من 5:00', Icons.rocket_launch_rounded, _coral, 50, (s) => s.runs.any((r) => r.splits.any((x) => x <= 300)) ? 1 : 0),
  BadgeDef('goal4', 'ملتزم', 'حقق هدف الأسبوع 4 أسابيع', Icons.verified_rounded, _leaf, 60, (s) => _ratio(_goalWeeks(s, 15), 4)),
  BadgeDef('runs25', '25 جولة', 'سجّل 25 جولة', Icons.directions_run_rounded, _sea, 40, (s) => _ratio(s.runs.length, 25)),
  BadgeDef('runs100', '100 جولة', 'سجّل 100 جولة', Icons.directions_run_rounded, _grape, 100, (s) => _ratio(s.runs.length, 100)),
];

// ───────────────────────── levels ─────────────────────────

/// XP needed to go from [level] to [level]+1.
int xpForNext(int level) => 100 + (level - 1) * 60;

const _titles = ['مبتدئ', 'عدّاء الحي', 'نَفَس طويل', 'فارس الكورنيش', 'صاحب العزيمة', 'محترف المسافات', 'أسطورة لفّة'];
String levelTitle(int level) => _titles[math.min((level - 1) ~/ 5, _titles.length - 1)];

/// Badges count only runs recorded in Laffa (imports can't unlock rewards).
RunStore ownRuns() => RunStore()..runs.addAll(runStore.runs.where((r) => !r.imported));

class Game extends ChangeNotifier {
  final List<LedgerEntry> ledger = [];
  final Set<String> badges = {};

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      ledger
        ..clear()
        ..addAll(((jsonDecode(sp.getString('ledger') ?? '[]')) as List).map((e) => LedgerEntry(e as Map<String, dynamic>)));
      badges
        ..clear()
        ..addAll((sp.getStringList('badges') ?? const []));
    } catch (e) {
      debugPrint('game load: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        'ledger',
        jsonEncode(ledger
            .map((e) => {'id': e.id, 'k': e.kind, 'l': e.label, 'p': e.points, 'x': e.xp, 't': e.at.millisecondsSinceEpoch})
            .toList()));
    await sp.setStringList('badges', badges.toList());
  }

  bool _has(String id) => ledger.any((e) => e.id == id);

  int get bonusPoints => ledger.fold(0, (a, e) => a + e.points);

  /// Spendable balance: distance points + all bonuses.
  int get balance => runStore.points + bonusPoints;

  int get xp => (runStore.totalKm * pointsPerKm).floor() + ledger.fold(0, (a, e) => a + e.xp);

  (int level, int into, int need) get level {
    var lv = 1, left = xp;
    while (left >= xpForNext(lv)) {
      left -= xpForNext(lv);
      lv++;
    }
    return (lv, left, xpForNext(lv));
  }

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Today's three challenges, picked from the pool by date and level.
  List<Challenge> challengesFor(DateTime day) {
    final lv = level.$1;
    final pool = _daily.where((c) => c.minLevel <= lv).toList();
    final rnd = math.Random(day.year * 10000 + day.month * 100 + day.day);
    pool.shuffle(rnd);
    // never two distance or two duration challenges together
    final picked = <Challenge>[];
    for (final c in pool) {
      final fam = c.id.replaceAll(RegExp(r'\d'), '');
      if (picked.any((p) => p.id.replaceAll(RegExp(r'\d'), '') == fam)) continue;
      picked.add(c);
      if (picked.length == 3) break;
    }
    return picked;
  }

  List<Run> runsOn(DateTime d) => runStore.runs.where((r) => r.flag == null && !r.imported && DateUtils.isSameDay(r.start, d)).toList();

  double challengeProgress(Challenge c, DateTime day) => c.progress(runsOn(day)).clamp(0, 1).toDouble();

  bool challengeDone(Challenge c, DateTime day) => _has('c:${c.id}:${_day(day)}');

  /// Weekly challenge: run on 4 different days this week.
  int get activeDaysThisWeek => runStore.thisWeek.where((r) => r.flag == null && r.km >= 1).map((r) => _day(r.start)).toSet().length;

  bool get weeklyDone => _has('w:${_day(RunStore.weekStart(DateTime.now()))}');

  /// Called after a run is saved. Credits bonuses and returns what was earned.
  Future<List<Reward>> afterRun(Run run) async {
    final out = <Reward>[];
    final day = run.start;
    final dayKey = _day(day);

    if (run.flag == null && !run.imported) {
      // Distance (already in the run; shown for the summary).
      final full = kmPoints(run.km);
      out.add(Reward('km', run.points < full ? 'المسافة (وصلت الحد اليومي 300)' : 'المسافة · 10 لكل كيلو كامل', run.points,
          xp: full, icon: Icons.straighten));

      // Streak bonus: first ≥1 km run of the day.
      if (run.km >= 1 && !_has('s:$dayKey')) {
        final s = runStore.streak;
        final pts = math.min(s * 5, 50);
        if (pts > 0) _credit('s:$dayKey', Reward('streak', 'مكافأة السلسلة · يوم $s', pts, icon: Icons.local_fire_department_rounded), out);
      }

      // Daily challenges.
      for (final c in challengesFor(day)) {
        if (!challengeDone(c, day) && challengeProgress(c, day) >= 1) {
          _credit('c:${c.id}:$dayKey', Reward('challenge', 'تحدي: ${c.title}', c.points, icon: c.icon), out);
        }
      }

      // Weekly challenge.
      final wk = _day(RunStore.weekStart(DateTime.now()));
      if (!_has('w:$wk') && activeDaysThisWeek >= 4) {
        _credit('w:$wk', Reward('weekly', 'تحدي الأسبوع: 4 أيام جري', 60, icon: Icons.event_available), out);
      }
    }

    // Badges.
    final own = ownRuns();
    for (final b in badgeDefs) {
      if (!badges.contains(b.id) && b.progress(own) >= 1) {
        badges.add(b.id);
        _credit('b:${b.id}', Reward('badge', 'وسام: ${b.title}', b.points, icon: b.icon), out);
      }
    }

    await _save();
    notifyListeners();
    return out;
  }

  /// Unlocks badges earned before this feature existed (no ceremony).
  Future<void> backfill() async {
    var changed = false;
    final own = ownRuns();
    for (final b in badgeDefs) {
      if (!badges.contains(b.id) && b.progress(own) >= 1) {
        badges.add(b.id);
        if (!_has('b:${b.id}')) ledger.add(LedgerEntry(Reward('badge', 'وسام: ${b.title}', b.points).toJson('b:${b.id}', DateTime.now())));
        changed = true;
      }
    }
    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  void _credit(String id, Reward r, List<Reward> out) {
    if (_has(id)) return;
    ledger.add(LedgerEntry(r.toJson(id, DateTime.now())));
    out.add(r);
  }
}

final game = Game();
