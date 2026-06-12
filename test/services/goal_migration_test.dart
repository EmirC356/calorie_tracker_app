import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/goal_service.dart';

/// Builds a database at the v4 schema (the state right before the Goals feature)
/// and seeds one row in every existing table.
Future<void> _createV4Database(String path) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 4,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE meals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            portion_grams REAL NOT NULL DEFAULT 0,
            nutrients TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            notes TEXT
          )''');
        await d.execute('''
          CREATE TABLE exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            durationMinutes INTEGER NOT NULL,
            caloriesBurned REAL NOT NULL,
            timestamp TEXT NOT NULL,
            notes TEXT,
            intensity TEXT NOT NULL
          )''');
        await d.execute('''
          CREATE TABLE meal_preps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            items_json TEXT NOT NULL,
            oil_sprays INTEGER,
            alcohol_type TEXT,
            alcohol_quantity INTEGER NOT NULL DEFAULT 0,
            total_nutrients_json TEXT NOT NULL,
            per_meal_nutrients_json TEXT NOT NULL,
            total_meal_count INTEGER NOT NULL,
            remaining_count INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )''');
        await d.execute('''
          CREATE TABLE weight_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            weight REAL NOT NULL,
            timestamp TEXT NOT NULL,
            isEmptyStomach INTEGER NOT NULL DEFAULT 0
          )''');
        await d.execute(
            'CREATE INDEX idx_meals_timestamp ON meals(timestamp)');
        await d.execute(
            'CREATE INDEX idx_exercises_timestamp ON exercises(timestamp)');
      },
    ),
  );

  await db.insert('meals', {
    'name': 'Chicken & rice',
    'portion_grams': 350.0,
    'nutrients': jsonEncode({'calories': 600, 'protein': 45, 'carbohydrates': 60, 'fat': 12}),
    'timestamp': DateTime(2026, 6, 1, 12).toIso8601String(),
    'notes': null,
  });
  await db.insert('exercises', {
    'name': 'Run',
    'durationMinutes': 30,
    'caloriesBurned': 320.0,
    'timestamp': DateTime(2026, 6, 1, 18).toIso8601String(),
    'notes': null,
    'intensity': 'medium',
  });
  await db.insert('weight_entries', {
    'weight': 74.5,
    'timestamp': DateTime(2026, 6, 1, 7).toIso8601String(),
    'isEmptyStomach': 1,
  });
  await db.close();
}

Future<bool> _tableExists(Database db, String name) async {
  final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?", [name]);
  return rows.isNotEmpty;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late String dbPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('goal_migration_test');
    dbPath = '${tmp.path}/calorie_tracker.db';
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('v4 → v10 migration keeps all data and adds goal/water/pause/makeup/checkin/proof', () async {
    await _createV4Database(dbPath);

    // Reopen through the real DatabaseService → runs every additive upgrade step.
    final service = DatabaseService(overridePath: dbPath);
    final db = await service.db;

    final version =
        (await db.rawQuery('PRAGMA user_version')).first.values.first;
    expect(version, 10);

    // v8 added the make-up column to meals + exercises.
    final mealCols = (await db.rawQuery('PRAGMA table_info(meals)')).map((c) => c['name']).toList();
    expect(mealCols, contains('makeup_for_date'));
    final exCols = (await db.rawQuery('PRAGMA table_info(exercises)')).map((c) => c['name']).toList();
    expect(exCols, contains('makeup_for_date'));
    // v9 added the check-in mirror table.
    expect(await _tableExists(db, 'checkins'), isTrue);
    // v10 added the proof_photo_ids column to goal_occurrences (additive, null).
    final occCols =
        (await db.rawQuery('PRAGMA table_info(goal_occurrences)')).map((c) => c['name']).toList();
    expect(occCols, contains('proof_photo_ids'));

    // Existing v4 tables and their rows are intact.
    expect(await _tableExists(db, 'meals'), isTrue);
    expect(await _tableExists(db, 'exercises'), isTrue);
    expect(await _tableExists(db, 'meal_preps'), isTrue);
    expect(await _tableExists(db, 'weight_entries'), isTrue);

    final meals = await db.query('meals');
    expect(meals, hasLength(1));
    expect(meals.first['name'], 'Chicken & rice');
    expect(meals.first['portion_grams'], 350.0);
    expect(await db.query('exercises'), hasLength(1));
    expect(await db.query('weight_entries'), hasLength(1));

    // New v5 + v6 tables exist.
    expect(await _tableExists(db, 'goals'), isTrue);
    expect(await _tableExists(db, 'goal_occurrences'), isTrue);
    expect(await _tableExists(db, 'goal_suggestions'), isTrue);
    expect(await _tableExists(db, 'water_entries'), isTrue);
    expect(await _tableExists(db, 'pause_history'), isTrue);

    // And the migrated DB is usable for goals end-to-end.
    final goals = GoalService(db: service);
    final id = await goals.createGoal(Goal(
      title: 'Gym 3x/week',
      category: GoalCategory.health,
      color: const Color(0xFFF5A524),
      startDate: DateTime(2026, 6, 9),
      recurrence: const RecurrenceWeekly(nTimesPerWeek: 3),
      createdAt: DateTime(2026, 6, 1),
    ));
    expect((await goals.getGoal(id))!.title, 'Gym 3x/week');

    await service.close();
  });
}
