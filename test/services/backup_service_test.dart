import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/goal_service.dart';
import 'package:calorie_tracker_app/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Meal meal() => Meal(
        name: 'Chicken & rice',
        portionGrams: 300,
        nutrients: NutrientInfo(
            calories: 600, protein: 45, carbohydrates: 60, fat: 12, fiber: 4, sugar: 2),
        timestamp: DateTime(2026, 6, 9, 12),
      );

  test('export → import into a fresh db restores goals, occurrences and meals', () async {
    final db1 = DatabaseService(overridePath: inMemoryDatabasePath);
    final goals1 = GoalService(db: db1);
    final gid = await goals1.createGoal(Goal(
      title: 'Read 30 min',
      category: GoalCategory.personal,
      color: const Color(0xFFB57EDC),
      startDate: DateTime(2026, 6, 1),
      recurrence: const RecurrenceDaily(),
      createdAt: DateTime(2026, 6, 1),
    ));
    await goals1.setOccurrenceStatus(
        goalId: gid, date: DateTime(2026, 6, 9), status: OccurrenceStatus.done);
    await db1.insertMeal(meal());

    final json = await BackupService(db: db1).exportToJsonString();
    await db1.close();

    // Restore into a brand-new empty database.
    final db2 = DatabaseService(overridePath: inMemoryDatabasePath);
    await BackupService(db: db2).importFromJsonString(json);
    final goals2 = GoalService(db: db2);

    final restoredGoals = await goals2.listGoals();
    expect(restoredGoals, hasLength(1));
    expect(restoredGoals.single.title, 'Read 30 min');
    expect(restoredGoals.single.id, gid); // id preserved

    final occ = await goals2.getOccurrence(gid, DateTime(2026, 6, 9));
    expect(occ, isNotNull);
    expect(occ!.status, OccurrenceStatus.done);

    final meals = await db2.getMeals();
    expect(meals, hasLength(1));
    expect(meals.single.name, 'Chicken & rice');
    await db2.close();
  });

  test('import wipes existing data first (full replace)', () async {
    final src = DatabaseService(overridePath: inMemoryDatabasePath);
    await GoalService(db: src).createGoal(Goal(
      title: 'From backup',
      category: GoalCategory.health,
      color: const Color(0xFFF5A524),
      startDate: DateTime(2026, 6, 1),
      recurrence: const RecurrenceNone(),
      createdAt: DateTime(2026, 6, 1),
    ));
    final json = await BackupService(db: src).exportToJsonString();
    await src.close();

    final dst = DatabaseService(overridePath: inMemoryDatabasePath);
    final dstGoals = GoalService(db: dst);
    await dstGoals.createGoal(Goal(
      title: 'Pre-existing',
      category: GoalCategory.home,
      color: const Color(0xFF4CC38A),
      startDate: DateTime(2026, 5, 1),
      recurrence: const RecurrenceNone(),
      createdAt: DateTime(2026, 5, 1),
    ));
    await BackupService(db: dst).importFromJsonString(json);

    final titles = (await dstGoals.listGoals()).map((g) => g.title).toList();
    expect(titles, ['From backup']); // pre-existing wiped
    await dst.close();
  });

  test('rejects a file that is not a Calorie Tracker backup', () async {
    final db = DatabaseService(overridePath: inMemoryDatabasePath);
    expect(() => BackupService(db: db).importFromMap({'app': 'something-else'}),
        throwsA(isA<FormatException>()));
    await db.close();
  });
}
