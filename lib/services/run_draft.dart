import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../state/game.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import 'health_sync.dart';
import 'reminders.dart';

/// A run in progress, written to disk every few seconds so it survives the
/// app being swiped away, killed by the system, or the phone restarting.
class RunDraft {
  RunDraft({
    required this.start,
    required this.secs,
    required this.meters,
    required this.path,
    required this.splits,
    required this.splitAt,
    required this.accepted,
    required this.rejected,
    required this.savedAt,
  });

  final DateTime start, savedAt;
  final int secs, splitAt, accepted, rejected;
  final double meters;
  final List<List<double>> path;
  final List<int> splits;

  static const _key = 'run_draft';

  Map<String, dynamic> toJson() => {
        's': start.millisecondsSinceEpoch,
        't': secs,
        'm': meters,
        'p': path,
        'k': splits,
        'ka': splitAt,
        'a': accepted,
        'r': rejected,
        'at': savedAt.millisecondsSinceEpoch,
      };

  factory RunDraft.fromJson(Map<String, dynamic> j) => RunDraft(
        start: DateTime.fromMillisecondsSinceEpoch(j['s'] as int),
        secs: j['t'] as int,
        meters: (j['m'] as num).toDouble(),
        path: ((j['p'] as List?) ?? const []).map((e) => (e as List).map((v) => (v as num).toDouble()).toList()).toList(),
        splits: ((j['k'] as List?) ?? const []).map((e) => e as int).toList(),
        splitAt: j['ka'] as int? ?? 0,
        accepted: j['a'] as int? ?? 0,
        rejected: j['r'] as int? ?? 0,
        savedAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      );

  /// Old drafts can still be saved, but continuing one hours later makes no sense.
  bool get resumable => DateTime.now().difference(savedAt).inMinutes < 60;

  Run toRun() => Run(
        start: start,
        secs: secs,
        meters: meters,
        path: path,
        splits: splits,
        flag: checkRun(meters: meters, secs: secs, rejected: rejected, accepted: accepted),
      );

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
  }

  static Future<RunDraft?> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null) return null;
      final d = RunDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return d.secs > 0 ? d : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_key);
    } catch (_) {}
  }
}

/// What the summary screen needs after a run is stored.
typedef Committed = ({Run run, List<Reward> rewards, int? levelUp, bool goalReached});

/// Stores a finished run and hands out its rewards. Shared by the live run
/// screen and the "save the unfinished run" recovery path.
Future<Committed> commitRun(Run run) async {
  final weekBefore = runStore.weekKm;
  await runStore.add(run);
  final lvBefore = game.level.$1;
  final rewards = await game.afterRun(run);
  final lvAfter = game.level.$1;
  await RunDraft.clear();
  reminders.celebrate(run, weekBefore: weekBefore);
  reminders.refresh();
  healthSync.export(run);
  return (
    run: run,
    rewards: rewards,
    levelUp: lvAfter > lvBefore ? lvAfter : null,
    goalReached: weekBefore < settings.goalKm && runStore.weekKm >= settings.goalKm,
  );
}
