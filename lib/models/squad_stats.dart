/// Weekly leaderboard stats for one member, derived from their hit-days.
class MemberStreak {
  final int daysHitLast7;
  final int currentStreak;
  final int longestStreak;
  const MemberStreak({
    required this.daysHitLast7,
    required this.currentStreak,
    required this.longestStreak,
  });
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Computes leaderboard stats from the set of calendar days the member hit
/// their goal. [today] anchors the window. Pure — unit-tested.
///
/// - daysHitLast7: hits within today..today-6.
/// - currentStreak: consecutive hit days ending today (or yesterday, so an
///   as-yet-unlogged today doesn't zero an ongoing streak). 0 if neither
///   today nor yesterday was hit.
/// - longestStreak: longest consecutive run within the last [window] days.
MemberStreak computeStreak(Set<DateTime> hitDays, DateTime today, {int window = 30}) {
  final hits = hitDays.map(_d).toSet();
  final t = _d(today);
  bool hit(DateTime d) => hits.contains(_d(d));

  var days7 = 0;
  for (var i = 0; i < 7; i++) {
    if (hit(t.subtract(Duration(days: i)))) days7++;
  }

  var current = 0;
  final anchor = hit(t) ? t : t.subtract(const Duration(days: 1));
  if (hit(anchor)) {
    var d = anchor;
    while (hit(d)) {
      current++;
      d = d.subtract(const Duration(days: 1));
    }
  }

  var longest = 0, run = 0;
  for (var i = window - 1; i >= 0; i--) {
    if (hit(t.subtract(Duration(days: i)))) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
  }

  return MemberStreak(daysHitLast7: days7, currentStreak: current, longestStreak: longest);
}
