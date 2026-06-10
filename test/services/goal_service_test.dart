import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/goal_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;
  late GoalService goals;
  const engine = RecurrenceEngine();

  setUp(() {
    db = DatabaseService(overridePath: inMemoryDatabasePath);
    goals = GoalService(db: db);
  });

  tearDown(() async => db.close());

  Goal dailyGoal(String title, DateTime start, {Color color = const Color(0xFFF5A524)}) =>
      Goal(
        title: title,
        category: GoalCategory.personal,
        color: color,
        startDate: start,
        recurrence: const RecurrenceDaily(),
        createdAt: DateTime(2026, 1, 1),
      );

  Future<List<Goal>> goalsOn(DateTime d) async {
    final all = await goals.listGoals();
    return all.where((g) => engine.occursOn(g, d)).toList();
  }

  final today = DateTime(2026, 6, 20);
  final start = today.subtract(const Duration(days: 10)); // 2026-06-10

  test('editThisAndFuture_includesTodayOccurrence', () async {
    final id = await goals.createGoal(dailyGoal('Old title', start));
    final original = (await goals.getGoal(id))!;

    await goals.editThisAndFuture(
      original: original,
      fromDate: today,
      edited: original.copyWith(title: 'New title'),
    );

    // Today shows the NEW title (today is included in the future split).
    final todays = await goalsOn(today);
    expect(todays, hasLength(1));
    expect(todays.single.title, 'New title');

    // Yesterday and earlier still show the OLD title.
    final yesterdays = await goalsOn(today.subtract(const Duration(days: 1)));
    expect(yesterdays, hasLength(1));
    expect(yesterdays.single.title, 'Old title');

    // Tomorrow and beyond show the NEW title.
    final tomorrows = await goalsOn(today.add(const Duration(days: 1)));
    expect(tomorrows.single.title, 'New title');

    // Exactly two goals now: the truncated original + the new series.
    expect((await goals.listGoals()), hasLength(2));
  });

  test('editThisAndFuture applies a non-title edit (color) to today too', () async {
    const newColor = Color(0xFF112233);
    final id = await goals.createGoal(dailyGoal('G', start));
    final original = (await goals.getGoal(id))!;

    await goals.editThisAndFuture(
      original: original,
      fromDate: today,
      edited: original.copyWith(color: newColor),
    );

    expect((await goalsOn(today)).single.color, newColor);
    expect((await goalsOn(today.subtract(const Duration(days: 1)))).single.color,
        const Color(0xFFF5A524));
  });

  test('editing from the start date edits the whole series in place (no split)', () async {
    final id = await goals.createGoal(dailyGoal('Old', start));
    final original = (await goals.getGoal(id))!;

    await goals.editThisAndFuture(
      original: original,
      fromDate: start, // == start → whole series
      edited: original.copyWith(title: 'Renamed'),
    );

    final all = await goals.listGoals();
    expect(all, hasLength(1)); // no new goal created
    expect(all.single.title, 'Renamed');
    expect((await goalsOn(today)).single.title, 'Renamed');
  });
}
