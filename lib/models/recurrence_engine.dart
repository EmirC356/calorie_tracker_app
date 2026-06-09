import 'goal.dart';
import 'recurrence.dart';
import 'date_helpers.dart';

/// Pure occurrence generation for goals. No IO.
///
/// The engine — not the `goal_occurrences` table — is the source of truth for
/// *which* dates a goal lands on. Occurrence rows are materialized lazily (on
/// user interaction or the end-of-period sweep); read paths that just render
/// the calendar call [occurrencesInRange] directly and write nothing.
///
/// Conventions:
/// - Week start is **Monday** (ISO-8601).
/// - A count-based weekly goal ("N times per week") emits exactly ONE anchor
///   occurrence per ISO week, dated to that week's **Monday**. The UI shows the
///   goal once that week and the tracked evaluator counts sessions across the
///   whole Mon–Sun week. Anchors never fall before the goal's start date: a
///   goal that starts mid-week first anchors on the following Monday.
class RecurrenceEngine {
  const RecurrenceEngine();

  /// The local date-only days in [from]..[to] (inclusive) that [g] occurs on.
  /// Honors [Goal.startDate] and [Goal.seriesEndDate]; never returns a date
  /// before the start date.
  List<DateTime> occurrencesInRange(Goal g, DateTime from, DateTime to) {
    final start0 = dateOnly(g.startDate);
    var lo = dateOnly(from);
    var hi = dateOnly(to);
    if (start0.isAfter(lo)) lo = start0; // clamp to start
    final end = g.seriesEndDate;
    if (end != null && end.isBefore(hi)) hi = end; // clamp to series end
    if (lo.isAfter(hi)) return const [];

    final r = g.recurrence;
    switch (r) {
      case RecurrenceNone():
        return (!start0.isBefore(lo) && !start0.isAfter(hi))
            ? [start0]
            : const [];

      case RecurrenceDaily():
        return daysInRange(lo, hi);

      case RecurrenceWeekly(
          weekdaysMask: final mask,
          nTimesPerWeek: final n,
        ):
        if (n != null) {
          // Count-based: one Monday anchor per week, on/after the start date.
          final out = <DateTime>[];
          for (var monday = mondayOf(lo);
              !monday.isAfter(hi);
              monday = monday.add(const Duration(days: 7))) {
            if (!monday.isBefore(lo) && !monday.isBefore(start0)) {
              out.add(monday);
            }
          }
          return out;
        }
        // Day-specific: each selected weekday in range.
        return [
          for (final d in daysInRange(lo, hi))
            if ((mask & weekdayBit(d.weekday)) != 0) d,
        ];

      case RecurrenceMonthly(dayOfMonth: final dom):
        final out = <DateTime>[];
        var y = lo.year, m = lo.month;
        while (true) {
          final d = DateTime(y, m, dom);
          if (d.isAfter(hi)) break;
          if (!d.isBefore(lo)) out.add(d);
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }
        return out;
    }
  }

  /// Whether [g] has an occurrence exactly on [date].
  bool occursOn(Goal g, DateTime date) =>
      occurrencesInRange(g, date, date).isNotEmpty;
}

/// The half-open [start, endExclusive) local window a tracked goal's metric is
/// summed/evaluated over for an occurrence on [date]. Day periods are that one
/// calendar day; week periods are the Mon–Sun ISO week containing [date].
({DateTime start, DateTime endExclusive}) periodRange(
    GoalPeriod period, DateTime date) {
  final d = dateOnly(date);
  switch (period) {
    case GoalPeriod.day:
      return (start: d, endExclusive: d.add(const Duration(days: 1)));
    case GoalPeriod.week:
      final m = mondayOf(d);
      return (start: m, endExclusive: m.add(const Duration(days: 7)));
  }
}
