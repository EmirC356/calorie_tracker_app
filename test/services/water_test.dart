import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/models/goal_evaluator.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/repos/goal_repos.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;
  setUp(() => db = DatabaseService(overridePath: inMemoryDatabasePath));
  tearDown(() async => db.close());

  test('water CRUD + repo sum a single day', () async {
    await db.insertWaterEntry(WaterEntry(amountMl: 250, timestamp: DateTime(2026, 6, 9, 8)));
    await db.insertWaterEntry(WaterEntry(amountMl: 500, timestamp: DateTime(2026, 6, 9, 12)));
    await db.insertWaterEntry(WaterEntry(amountMl: 300, timestamp: DateTime(2026, 6, 10, 8))); // next day

    final today = await db.getWaterEntriesByDate(DateTime(2026, 6, 9));
    expect(today, hasLength(2));
    expect(today.fold<int>(0, (s, e) => s + e.amountMl), 750);

    final repo = DbWaterRepo(db);
    expect(await repo.waterMlInRange(DateTime(2026, 6, 9), DateTime(2026, 6, 10)), 750);
  });

  test('a waterMl tracked goal now evaluates instead of "not enabled"', () async {
    await db.insertWaterEntry(WaterEntry(amountMl: 1200, timestamp: DateTime(2026, 6, 9, 9)));
    await db.insertWaterEntry(WaterEntry(amountMl: 900, timestamp: DateTime(2026, 6, 9, 15)));

    final goal = Goal(
      title: 'Drink 2L',
      category: GoalCategory.health,
      color: const Color(0xFFF5A524),
      type: GoalType.tracked,
      metric: TrackedMetric.waterMl,
      comparator: Comparator.greaterThanOrEqual,
      target: 2000,
      period: GoalPeriod.day,
      startDate: DateTime(2026, 6, 1),
      recurrence: const RecurrenceDaily(),
      createdAt: DateTime(2026, 6, 1),
    );

    final r = await const GoalEvaluator().evaluate(
      goal: goal,
      occurrenceDate: DateTime(2026, 6, 9),
      meals: DbMealRepo(db),
      exercises: DbExerciseRepo(db),
      weights: DbWeightRepo(db),
      water: DbWaterRepo(db),
    );
    expect(r.metricValue, 2100);
    expect(r.status, OccurrenceStatus.done); // 2100 ≥ 2000
  });
}
