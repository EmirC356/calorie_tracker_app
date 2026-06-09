import 'goal_visible.dart';
import 'date_helpers.dart';

/// Weekly goal stats for a squadmate, derived from their squad-visible goal
/// occurrences (`goalsVisible` docs).
class GoalVisibleStats {
  final int done7d;
  final int decided7d; // done + failed in the last 7 days
  final int currentStreak;
  final int longestStreak30d;

  const GoalVisibleStats({
    this.done7d = 0,
    this.decided7d = 0,
    this.currentStreak = 0,
    this.longestStreak30d = 0,
  });

  /// done / (done + failed) over the last 7 days; 0 when nothing is decided.
  double get hitRate7d => decided7d == 0 ? 0 : done7d / decided7d;
}

/// Computes [GoalVisibleStats] from [docs]. A calendar day is "successful" when
/// it has at least one `done` occurrence and no `failed` one (the day's goals
/// were all met). Streaks are measured over successful days; the current streak
/// survives an as-yet-undecided today (mirrors the squad leaderboard logic).
GoalVisibleStats computeGoalVisibleStats(List<GoalVisible> docs, {DateTime? asOf}) {
  final today = dateOnly(asOf ?? DateTime.now());

  // Tally per-day done/failed.
  final done = <DateTime, int>{};
  final failed = <DateTime, int>{};
  for (final g in docs) {
    if (g.date.isEmpty) continue;
    final d = parseYmd(g.date);
    if (g.status == 'done') {
      done[d] = (done[d] ?? 0) + 1;
    } else if (g.status == 'failed') {
      failed[d] = (failed[d] ?? 0) + 1;
    }
  }

  bool success(DateTime d) =>
      (done[dateOnly(d)] ?? 0) > 0 && (failed[dateOnly(d)] ?? 0) == 0;

  var done7d = 0, decided7d = 0;
  for (var i = 0; i < 7; i++) {
    final d = dateOnly(today.subtract(Duration(days: i)));
    done7d += done[d] ?? 0;
    decided7d += (done[d] ?? 0) + (failed[d] ?? 0);
  }

  var current = 0;
  final anchor = success(today) ? today : today.subtract(const Duration(days: 1));
  if (success(anchor)) {
    var d = anchor;
    while (success(d)) {
      current++;
      d = d.subtract(const Duration(days: 1));
    }
  }

  var longest = 0, run = 0;
  for (var i = 29; i >= 0; i--) {
    if (success(today.subtract(Duration(days: i)))) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
  }

  return GoalVisibleStats(
    done7d: done7d,
    decided7d: decided7d,
    currentStreak: current,
    longestStreak30d: longest,
  );
}
