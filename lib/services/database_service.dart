import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/index.dart';
import 'dart:convert';

class DatabaseService {
  static const String _dbName = 'calorie_tracker.db';
  static const int _dbVersion = 2;

  static const String tablesMeals = 'meals';
  static const String tablesExercises = 'exercises';
  static const String tablesMealPreps = 'meal_preps';
  static const String tablesWeightEntries = 'weight_entries';

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createMealsTable(db);
    await _createExercisesTable(db);
    await _createMealPrepsTable(db);
    await _createWeightEntriesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMealPrepsTable(db);
      await _createWeightEntriesTable(db);
    }
  }

  Future<void> _createMealsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesMeals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        weight REAL NOT NULL,
        nutrients TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<void> _createExercisesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesExercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        caloriesBurned REAL NOT NULL,
        timestamp TEXT NOT NULL,
        notes TEXT,
        intensity TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMealPrepsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesMealPreps (
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
      )
    ''');
  }

  Future<void> _createWeightEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesWeightEntries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL NOT NULL,
        timestamp TEXT NOT NULL,
        isEmptyStomach INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ─── Meal operations ───────────────────────────────────────────────────────

  Future<int> insertMeal(Meal meal) async {
    final database = await db;
    return await database.insert(tablesMeals, {
      'name': meal.name,
      'weight': meal.weight,
      'nutrients': jsonEncode(meal.nutrients.toJson()),
      'timestamp': meal.timestamp.toIso8601String(),
      'notes': meal.notes,
    });
  }

  Future<List<Meal>> getMeals() async {
    final database = await db;
    final maps = await database.query(tablesMeals);
    return maps.map(_mealFromMap).toList();
  }

  Future<List<Meal>> getMealsByDate(DateTime date) async {
    final database = await db;
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final maps = await database.query(
      tablesMeals,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return maps.map(_mealFromMap).toList();
  }

  Meal _mealFromMap(Map<String, dynamic> m) => Meal(
        id: m['id'] as int?,
        name: m['name'] as String,
        weight: (m['weight'] as num).toDouble(),
        nutrients: NutrientInfo.fromJson(
            jsonDecode(m['nutrients'] as String) as Map<String, dynamic>),
        timestamp: DateTime.parse(m['timestamp'] as String),
        notes: m['notes'] as String?,
      );

  Future<int> deleteMeal(int id) async {
    final database = await db;
    return await database.delete(tablesMeals, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Exercise operations ────────────────────────────────────────────────────

  Future<int> insertExercise(Exercise exercise) async {
    final database = await db;
    return await database.insert(tablesExercises, {
      'name': exercise.name,
      'durationMinutes': exercise.durationMinutes,
      'caloriesBurned': exercise.caloriesBurned,
      'timestamp': exercise.timestamp.toIso8601String(),
      'notes': exercise.notes,
      'intensity': exercise.intensity,
    });
  }

  Future<List<Exercise>> getExercises() async {
    final database = await db;
    final maps = await database.query(tablesExercises);
    return maps.map(_exerciseFromMap).toList();
  }

  Future<List<Exercise>> getExercisesByDate(DateTime date) async {
    final database = await db;
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final maps = await database.query(
      tablesExercises,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return maps.map(_exerciseFromMap).toList();
  }

  Exercise _exerciseFromMap(Map<String, dynamic> m) => Exercise(
        id: m['id'] as int?,
        name: m['name'] as String,
        durationMinutes: m['durationMinutes'] as int,
        caloriesBurned: (m['caloriesBurned'] as num).toDouble(),
        timestamp: DateTime.parse(m['timestamp'] as String),
        notes: m['notes'] as String?,
        intensity: m['intensity'] as String,
      );

  Future<int> deleteExercise(int id) async {
    final database = await db;
    return await database
        .delete(tablesExercises, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Meal prep operations ───────────────────────────────────────────────────

  Future<int> insertMealPrep(MealPrep prep) async {
    final database = await db;
    return await database.insert(tablesMealPreps, prep.toDbMap());
  }

  Future<List<MealPrep>> getMealPreps() async {
    final database = await db;
    final maps = await database.query(tablesMealPreps,
        orderBy: 'created_at DESC');
    return maps.map(MealPrep.fromDbMap).toList();
  }

  Future<int> updateMealPrepRemaining(int id, int remainingCount) async {
    final database = await db;
    return await database.update(
      tablesMealPreps,
      {'remaining_count': remainingCount},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMealPrep(int id) async {
    final database = await db;
    return await database
        .delete(tablesMealPreps, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Weight entry operations ────────────────────────────────────────────────

  Future<int> insertWeightEntry(WeightEntry entry) async {
    final database = await db;
    return await database.insert(tablesWeightEntries, {
      'weight': entry.weight,
      'timestamp': entry.timestamp.toIso8601String(),
      'isEmptyStomach': entry.isEmptyStomach ? 1 : 0,
    });
  }

  Future<List<WeightEntry>> getWeightEntries() async {
    final database = await db;
    final maps = await database.query(tablesWeightEntries,
        orderBy: 'timestamp ASC');
    return maps.map(WeightEntry.fromJson).toList();
  }

  Future<int> deleteWeightEntry(int id) async {
    final database = await db;
    return await database
        .delete(tablesWeightEntries, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final database = await db;
    database.close();
  }
}
