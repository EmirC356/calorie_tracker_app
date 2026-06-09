import '../models/index.dart';
import 'goal_service.dart';

/// Evaluates a tracked goal occurrence to a final status. Supplied by the caller
/// so the sweep doesn't depend on the (Phase 3) GoalEvaluator + repos directly,
/// which keeps it unit-testable with a fake. Returns null to leave the
/// occurrence unmaterialized (e.g. when tracking data isn't available yet).
typedef TrackedEvaluator = Future<GoalEvaluationResult?> Function(
    Goal goal, DateTime occurrenceDate);

/// Finalizes the status of past goal occurrences whose period has fully ended.
///
/// Materialization stays lazy: the recurrence engine is the source of truth and
/// rows are written only for occurrences in the past that the user never
/// touched, so a viewed calendar never writes. The sweep is **idempotent** — an
/// occurrence that already has a row (including a user-set `done`) is skipped.
class GoalSweepService {
  final GoalService _goals;
  final RecurrenceEngine _engine;

  GoalSweepService(this._goals, {RecurrenceEngine engine = const RecurrenceEngine()})
      : _engine = engine;

  /// Walks active goals and records a final status for every occurrence whose
  /// period ended strictly before [asOf]'s day and that has no row yet:
  ///   - manual goals → `failed` (the day passed and it was never marked done);
  ///   - tracked goals → [evaluateTracked]; if that's null or returns null the
  ///     occurrence is left unmaterialized.
  ///
  /// [since] bounds the backfill window (defaults to 90 days before [asOf]) so
  /// a long-running daily goal doesn't materialize years of history at once.
  /// Returns the number of occurrence rows written.
  Future<int> sweepFinalizePastOccurrences({
    required DateTime asOf,
    DateTime? since,
    TrackedEvaluator? evaluateTracked,
  }) async {
    final today = dateOnly(asOf);
    final floor = dateOnly(since ?? today.subtract(const Duration(days: 90)));

    var written = 0;
    for (final goal in await _goals.listGoals(onlyActive: true)) {
      final windowStart =
          goal.startDate.isAfter(floor) ? dateOnly(goal.startDate) : floor;
      if (windowStart.isAfter(today)) continue;

      final dates = _engine.occurrencesInRange(goal, windowStart, today);
      for (final d in dates) {
        // Only finalize occurrences whose whole period is in the past.
        final period = goal.period ?? GoalPeriod.day;
        final endExclusive = goal.isTracked
            ? periodRange(period, d).endExclusive
            : d.add(const Duration(days: 1));
        if (endExclusive.isAfter(today)) continue; // period not over yet

        // Idempotent: never overwrite an existing row (incl. user 'done').
        if (await _goals.getOccurrence(goal.id!, d) != null) continue;

        if (goal.isTracked) {
          final result = evaluateTracked == null
              ? null
              : await evaluateTracked(goal, d);
          if (result == null) continue; // leave unmaterialized
          await _goals.setOccurrenceStatus(
            goalId: goal.id!,
            date: d,
            status: result.status,
            periodValueCached: result.metricValue,
          );
        } else {
          await _goals.setOccurrenceStatus(
            goalId: goal.id!,
            date: d,
            status: OccurrenceStatus.failed,
          );
        }
        written++;
      }
    }
    return written;
  }
}
