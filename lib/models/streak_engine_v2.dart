/// Streak engine v2 — a single **pure** module (no Firestore / SQLite / IO).
///
/// Given a member's chronological per-day history (each day a [StreakStatus],
/// plus a `redeemed` flag for a missed day rescued by a make-up) it derives the
/// streak insights ten of the squad features rely on. Build/keep this dependency
/// free so everything that consumes it inherits its correctness.
///
/// Rules:
/// - `hit` extends the streak by 1.0.
/// - `missed` resets it to 0 — UNLESS it was redeemed by a make-up, in which
///   case it contributes 0.5 and does NOT break (the visible "13.5 day streak").
/// - `paused` is a freeze: it neither extends nor breaks (carries the value).
/// - `inProgress` is today, not yet finalized: it neither extends nor breaks.
library;

enum StreakStatus { hit, inProgress, missed, paused }

/// One finalized-or-pending day in a member's history (date-only).
class StreakDay {
  final DateTime date;
  final StreakStatus status;

  /// True when [status] is `missed` but a make-up redeemed it (counts 0.5,
  /// doesn't break the chain). Ignored for non-missed statuses.
  final bool redeemed;

  const StreakDay({required this.date, required this.status, this.redeemed = false});
}

class StreakInsights {
  /// Current streak ending at the last history day. Fractional when a make-up
  /// redeemed a miss (e.g. 13.5).
  final double currentStreak;

  /// Largest streak value reached anywhere in the history.
  final double longestStreak;

  /// Today's day is `inProgress` and it's past 18:00 local (needs `now`).
  final bool atRiskFlag;

  /// The most-recently-finalized day broke a streak that was ≥ `breakThreshold`.
  final bool brokenToday;

  const StreakInsights({
    required this.currentStreak,
    required this.longestStreak,
    required this.atRiskFlag,
    required this.brokenToday,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Computes [StreakInsights] from a chronological [history] (oldest first).
///
/// [now] enables [StreakInsights.atRiskFlag]; pass the local time. [breakThreshold]
/// is the minimum streak length whose break counts as "loud" (default 5, the
/// streak-broken-broadcast threshold).
StreakInsights computeStreakV2(
  List<StreakDay> history, {
  DateTime? now,
  int breakThreshold = 5,
}) {
  double current = 0;
  double longest = 0;

  // Index of the last finalized (non-inProgress) day, for brokenToday.
  int lastFinalized = -1;
  for (var i = 0; i < history.length; i++) {
    if (history[i].status != StreakStatus.inProgress) lastFinalized = i;
  }

  var brokenToday = false;
  for (var i = 0; i < history.length; i++) {
    final day = history[i];
    final before = current;
    switch (day.status) {
      case StreakStatus.hit:
        current += 1;
      case StreakStatus.missed:
        if (day.redeemed) {
          current += 0.5; // rescued by a make-up — chain survives
        } else {
          current = 0; // hard break
        }
      case StreakStatus.paused:
        break; // freeze
      case StreakStatus.inProgress:
        break; // pending — today not yet finalized
    }
    if (current > longest) longest = current;

    if (i == lastFinalized &&
        day.status == StreakStatus.missed &&
        !day.redeemed) {
      brokenToday = before >= breakThreshold;
    }
  }

  var atRisk = false;
  if (history.isNotEmpty && now != null) {
    final last = history.last;
    if (_dateOnly(last.date) == _dateOnly(now) &&
        last.status == StreakStatus.inProgress &&
        now.hour >= 18) {
      atRisk = true;
    }
  }

  return StreakInsights(
    currentStreak: current,
    longestStreak: longest,
    atRiskFlag: atRisk,
    brokenToday: brokenToday,
  );
}
