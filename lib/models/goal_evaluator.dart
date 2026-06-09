import '../services/repos/goal_repos.dart';
import 'goal.dart';
import 'goal_evaluation_result.dart';
import 'goal_occurrence.dart';
import 'recurrence_engine.dart';
import 'date_helpers.dart';

/// Evaluates a tracked goal occurrence against the app's existing meal /
/// exercise / weight (/ future water) data, read through narrow [MealRepo] etc.
/// ports. Pure orchestration — all IO is behind the injected repos, so it's
/// unit-tested with in-memory fakes.
///
/// Pass rules:
///  - cap (≤): metric ≤ target → done; else open during the period, failed
///    once the period has ended.
///  - floor (≥): metric ≥ target → done; else open during the period, failed
///    once the period has ended.
///
/// Progress percent (for the UI ring):
///  - floor: min(metric / target, 1) · 100.
///  - cap: clamp((target − metric) / target · 100, 0, 100) — headroom left,
///    0 when overshot.
class GoalEvaluator {
  const GoalEvaluator();

  Future<GoalEvaluationResult> evaluate({
    required Goal goal,
    required DateTime occurrenceDate,
    required MealRepo meals,
    required ExerciseRepo exercises,
    required WeightRepo weights,
    WaterRepo? water,
    DateTime? now,
  }) async {
    if (!goal.isTracked ||
        goal.metric == null ||
        goal.comparator == null ||
        goal.target == null) {
      return const GoalEvaluationResult(
          status: OccurrenceStatus.open, message: 'Not a tracked goal');
    }

    final period = goal.period ?? GoalPeriod.day;
    final range = periodRange(period, occurrenceDate);
    final ref = dateOnly(now ?? DateTime.now());
    final periodOver = !range.endExclusive.isAfter(ref);
    final target = goal.target!;

    double? value;
    String? message;

    switch (goal.metric!) {
      case TrackedMetric.kcalTotal:
        final ms = await meals.mealsInRange(range.start, range.endExclusive);
        value = ms.fold<double>(0.0, (s, m) => s + m.nutrients.calories);
      case TrackedMetric.proteinG:
        final ms = await meals.mealsInRange(range.start, range.endExclusive);
        value = ms.fold<double>(0.0, (s, m) => s + m.nutrients.protein);
      case TrackedMetric.exerciseMinutes:
        final es =
            await exercises.exercisesInRange(range.start, range.endExclusive);
        value = es.fold<double>(0.0, (s, e) => s + e.durationMinutes);
      case TrackedMetric.exerciseSessionCount:
        final es =
            await exercises.exercisesInRange(range.start, range.endExclusive);
        final minDur = goal.effectiveMinDurationMin;
        value =
            es.where((e) => e.durationMinutes >= minDur).length.toDouble();
      case TrackedMetric.weightDeltaKg:
        final ws =
            await weights.weightEntriesInRange(range.start, range.endExclusive);
        if (ws.isEmpty) {
          // Can't evaluate without data — never auto-fails.
          return GoalEvaluationResult(
              status: OccurrenceStatus.open,
              targetValue: target,
              message: 'No weight entries in period');
        }
        final sorted = [...ws]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        value = sorted.last.weight - sorted.first.weight; // latest − first
      case TrackedMetric.waterMl:
        if (water == null) {
          return GoalEvaluationResult(
              status: OccurrenceStatus.open,
              targetValue: target,
              message: 'Water tracking not enabled');
        }
        value = await water.waterMlInRange(range.start, range.endExclusive);
    }

    // Every reachable path above assigned a value; the unevaluable metrics
    // (no weight data, water tracking off) returned early.
    final v = value;
    final isCap = goal.comparator == Comparator.lessThanOrEqual;
    final pass = isCap ? v <= target : v >= target;
    final status = pass
        ? OccurrenceStatus.done
        : (periodOver ? OccurrenceStatus.failed : OccurrenceStatus.open);

    final double progress;
    if (target == 0) {
      progress = pass ? 100 : 0;
    } else if (isCap) {
      progress = (((target - v) / target) * 100).clamp(0, 100).toDouble();
    } else {
      progress = ((v / target) * 100).clamp(0, 100).toDouble();
    }

    return GoalEvaluationResult(
      status: status,
      metricValue: v,
      targetValue: target,
      progressPercent: progress,
      message: message,
    );
  }
}
