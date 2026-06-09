import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/models/goal_evaluator.dart';
import 'package:calorie_tracker_app/services/repos/goal_repos.dart';

// ─── In-memory fakes ──────────────────────────────────────────────────────────
class FakeMealRepo implements MealRepo {
  final List<Meal> items;
  FakeMealRepo([this.items = const []]);
  @override
  Future<List<Meal>> mealsInRange(DateTime s, DateTime e) async =>
      items.where((m) => !m.timestamp.isBefore(s) && m.timestamp.isBefore(e)).toList();
}

class FakeExerciseRepo implements ExerciseRepo {
  final List<Exercise> items;
  FakeExerciseRepo([this.items = const []]);
  @override
  Future<List<Exercise>> exercisesInRange(DateTime s, DateTime e) async =>
      items.where((x) => !x.timestamp.isBefore(s) && x.timestamp.isBefore(e)).toList();
}

class FakeWeightRepo implements WeightRepo {
  final List<WeightEntry> items;
  FakeWeightRepo([this.items = const []]);
  @override
  Future<List<WeightEntry>> weightEntriesInRange(DateTime s, DateTime e) async =>
      items.where((w) => !w.timestamp.isBefore(s) && w.timestamp.isBefore(e)).toList();
}

class FakeWaterRepo implements WaterRepo {
  final double total;
  FakeWaterRepo(this.total);
  @override
  Future<double> waterMlInRange(DateTime s, DateTime e) async => total;
}

// ─── Fixtures ─────────────────────────────────────────────────────────────────
Meal meal(DateTime t, {double cal = 0, double protein = 0}) => Meal(
      name: 'm',
      portionGrams: 0,
      nutrients: NutrientInfo(
          calories: cal, protein: protein, carbohydrates: 0, fat: 0, fiber: 0, sugar: 0),
      timestamp: t,
    );

Exercise ex(DateTime t, int minutes) =>
    Exercise(name: 'e', durationMinutes: minutes, caloriesBurned: 0, timestamp: t);

WeightEntry wt(DateTime t, double kg) =>
    WeightEntry(weight: kg, timestamp: t, isEmptyStomach: false);

Goal tracked({
  required TrackedMetric metric,
  required Comparator comparator,
  required double target,
  GoalPeriod period = GoalPeriod.day,
  int? minDurationMin,
  DateTime? start,
}) =>
    Goal(
      title: 'g',
      category: GoalCategory.health,
      color: const Color(0xFFF5A524),
      type: GoalType.tracked,
      metric: metric,
      comparator: comparator,
      target: target,
      period: period,
      minDurationMin: minDurationMin,
      startDate: start ?? DateTime(2026, 6, 1),
      recurrence: const RecurrenceDaily(),
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  const evaluator = GoalEvaluator();
  final tue = DateTime(2026, 6, 9); // a Tuesday

  Future<GoalEvaluationResult> eval(
    Goal goal, {
    DateTime? on,
    List<Meal> meals = const [],
    List<Exercise> exercises = const [],
    List<WeightEntry> weights = const [],
    WaterRepo? water,
    DateTime? now,
  }) =>
      evaluator.evaluate(
        goal: goal,
        occurrenceDate: on ?? tue,
        meals: FakeMealRepo(meals),
        exercises: FakeExerciseRepo(exercises),
        weights: FakeWeightRepo(weights),
        water: water,
        now: now,
      );

  group('kcalTotal (cap ≤ 2000, day)', () {
    final g = tracked(metric: TrackedMetric.kcalTotal, comparator: Comparator.lessThanOrEqual, target: 2000);
    test('under cap → done', () async {
      final r = await eval(g, meals: [meal(tue, cal: 1800)]);
      expect(r.status, OccurrenceStatus.done);
      expect(r.metricValue, 1800);
      expect(r.progressPercent, closeTo(10, 0.001)); // (2000-1800)/2000*100
    });
    test('over cap, still in period → open', () async {
      final r = await eval(g, meals: [meal(tue, cal: 2200)], now: tue);
      expect(r.status, OccurrenceStatus.open);
    });
    test('over cap, period ended → failed', () async {
      final r = await eval(g, meals: [meal(tue, cal: 2200)], now: DateTime(2026, 6, 10));
      expect(r.status, OccurrenceStatus.failed);
      expect(r.progressPercent, 0); // overshot
    });
  });

  group('proteinG (floor ≥ 150, day)', () {
    final g = tracked(metric: TrackedMetric.proteinG, comparator: Comparator.greaterThanOrEqual, target: 150);
    test('meets floor → done', () async {
      final r = await eval(g, meals: [meal(tue, protein: 80), meal(tue, protein: 90)]);
      expect(r.status, OccurrenceStatus.done);
      expect(r.metricValue, 170);
      expect(r.progressPercent, 100);
    });
    test('below floor, period ended → failed (progress shows fraction)', () async {
      final r = await eval(g, meals: [meal(tue, protein: 75)], now: DateTime(2026, 6, 10));
      expect(r.status, OccurrenceStatus.failed);
      expect(r.progressPercent, closeTo(50, 0.001));
    });
    test('below floor, still in period → open', () async {
      final r = await eval(g, meals: [meal(tue, protein: 75)], now: tue);
      expect(r.status, OccurrenceStatus.open);
    });
  });

  group('exerciseMinutes (floor ≥ 30, day)', () {
    final g = tracked(metric: TrackedMetric.exerciseMinutes, comparator: Comparator.greaterThanOrEqual, target: 30);
    test('enough minutes → done', () async {
      final r = await eval(g, exercises: [ex(tue, 20), ex(tue, 15)]);
      expect(r.status, OccurrenceStatus.done);
      expect(r.metricValue, 35);
    });
    test('not enough, period ended → failed', () async {
      final r = await eval(g, exercises: [ex(tue, 20)], now: DateTime(2026, 6, 10));
      expect(r.status, OccurrenceStatus.failed);
    });
  });

  group('exerciseSessionCount (floor ≥ 3, minDuration 20, day)', () {
    final g = tracked(
        metric: TrackedMetric.exerciseSessionCount,
        comparator: Comparator.greaterThanOrEqual,
        target: 3,
        minDurationMin: 20);
    test('counts only sessions ≥ minDuration', () async {
      final r = await eval(g, exercises: [ex(tue, 25), ex(tue, 30), ex(tue, 22), ex(tue, 10)]);
      expect(r.metricValue, 3); // the 10-min session is excluded
      expect(r.status, OccurrenceStatus.done);
    });
    test('too few qualifying sessions, period ended → failed', () async {
      final r = await eval(g, exercises: [ex(tue, 25), ex(tue, 10)], now: DateTime(2026, 6, 10));
      expect(r.metricValue, 1);
      expect(r.status, OccurrenceStatus.failed);
    });
  });

  group('weightDeltaKg (week)', () {
    final mon = DateTime(2026, 6, 8); // week Jun 8..14
    test('cap ≤ -1 (lose ≥1kg) met → done', () async {
      final g = tracked(
          metric: TrackedMetric.weightDeltaKg,
          comparator: Comparator.lessThanOrEqual,
          target: -1,
          period: GoalPeriod.week);
      final r = await eval(g,
          on: mon, weights: [wt(DateTime(2026, 6, 8), 75), wt(DateTime(2026, 6, 13), 73)]);
      expect(r.metricValue, closeTo(-2, 0.001));
      expect(r.status, OccurrenceStatus.done);
    });
    test('floor ≥ 1 (gain) not met, period ended → failed', () async {
      final g = tracked(
          metric: TrackedMetric.weightDeltaKg,
          comparator: Comparator.greaterThanOrEqual,
          target: 1,
          period: GoalPeriod.week);
      final r = await eval(g,
          on: mon,
          weights: [wt(DateTime(2026, 6, 8), 75), wt(DateTime(2026, 6, 13), 75.2)],
          now: DateTime(2026, 6, 15));
      expect(r.status, OccurrenceStatus.failed);
    });
    test('no weight data → open with message, never auto-fails', () async {
      final g = tracked(
          metric: TrackedMetric.weightDeltaKg,
          comparator: Comparator.lessThanOrEqual,
          target: -1,
          period: GoalPeriod.week);
      final r = await eval(g, on: mon, weights: const [], now: DateTime(2026, 6, 30));
      expect(r.status, OccurrenceStatus.open);
      expect(r.message, contains('No weight'));
    });
  });

  group('waterMl (floor ≥ 2000, day)', () {
    final g = tracked(metric: TrackedMetric.waterMl, comparator: Comparator.greaterThanOrEqual, target: 2000);
    test('no water repo → open, never auto-fails', () async {
      final r = await eval(g, water: null, now: DateTime(2026, 6, 30));
      expect(r.status, OccurrenceStatus.open);
      expect(r.message, contains('Water tracking not enabled'));
    });
    test('enough water → done', () async {
      final r = await eval(g, water: FakeWaterRepo(2500));
      expect(r.status, OccurrenceStatus.done);
    });
    test('too little, period ended → failed', () async {
      final r = await eval(g, water: FakeWaterRepo(1000), now: DateTime(2026, 6, 10));
      expect(r.status, OccurrenceStatus.failed);
    });
  });

  group('weekly bucket boundaries (Mon inclusive, next Mon exclusive)', () {
    final g = tracked(
        metric: TrackedMetric.kcalTotal,
        comparator: Comparator.lessThanOrEqual,
        target: 100000,
        period: GoalPeriod.week);
    test('only meals within the Mon–Sun week are summed', () async {
      final r = await eval(
        g,
        on: DateTime(2026, 6, 10), // Wed → week Jun 8..14
        meals: [
          meal(DateTime(2026, 6, 7, 23), cal: 999), // Sun before — excluded
          meal(DateTime(2026, 6, 8), cal: 100), // Mon — included (boundary)
          meal(DateTime(2026, 6, 14, 23), cal: 200), // Sun — included
          meal(DateTime(2026, 6, 15), cal: 999), // next Mon — excluded (boundary)
        ],
      );
      expect(r.metricValue, 300);
    });
  });

  test('non-tracked goal returns open', () async {
    final g = Goal(
      title: 'manual',
      category: GoalCategory.home,
      color: const Color(0xFF4CC38A),
      type: GoalType.manual,
      startDate: DateTime(2026, 6, 9),
      recurrence: const RecurrenceNone(),
      createdAt: DateTime(2026, 6, 1),
    );
    final r = await eval(g);
    expect(r.status, OccurrenceStatus.open);
  });
}
