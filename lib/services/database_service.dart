import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/index.dart';

class DatabaseService {
  static const String _dbName = 'calorie_tracker.db';
  static const int _dbVersion = 4;

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
    await _createTimestampIndexes(db);
  }

  /// Migration convention
  /// ---------------------
  /// To change the schema: bump [_dbVersion] and add one `if (oldVersion < N)`
  /// block below. Every step MUST be additive — create tables, add columns,
  /// or create indexes. Never DROP a table/column or rewrite existing user
  /// rows. Add new columns with `ALTER TABLE ... ADD COLUMN` (with a default
  /// so existing rows stay valid). Before any step that rewrites existing
  /// rows, call [backupToJson] first so a failed migration can be recovered.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMealPrepsTable(db);
      await _createWeightEntriesTable(db);
    }
    if (oldVersion < 3) {
      await _createTimestampIndexes(db);
    }
    if (oldVersion < 4) {
      // Rename meals.weight -> meals.portion_grams. Additive: add the new
      // column and copy values; the legacy 'weight' column is left in place
      // (unused) so no user data is dropped. Back up first since we touch rows.
      await backupToJson(db, reason: 'v4_portion_grams');
      final cols = await db.rawQuery('PRAGMA table_info($tablesMeals)');
      final names = cols.map((c) => c['name']).toSet();
      if (!names.contains('portion_grams')) {
        await db.execute(
            'ALTER TABLE $tablesMeals ADD COLUMN portion_grams REAL NOT NULL DEFAULT 0');
      }
      if (names.contains('weight')) {
        await db.execute(
            'UPDATE $tablesMeals SET portion_grams = weight WHERE portion_grams = 0');
      }
    }
  }

  /// Indexes the date columns the dashboard queries hit on every load.
  Future<void> _createTimestampIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_meals_timestamp ON $tablesMeals(timestamp)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_exercises_timestamp ON $tablesExercises(timestamp)');
  }

  Future<bool> _tableExists(Database db, String name) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [name],
    );
    return rows.isNotEmpty;
  }

  /// Best-effort safety net: dumps every existing table to a JSON file next to
  /// the database before a risky migration. Returns the file path, or null if
  /// the backup could not be written (a backup failure must never block a
  /// migration). [reason] is used in the filename.
  Future<String?> backupToJson(Database db, {required String reason}) async {
    try {
      final dump = <String, dynamic>{};
      for (final table in [
        tablesMeals,
        tablesExercises,
        tablesMealPreps,
        tablesWeightEntries,
      ]) {
        if (await _tableExists(db, table)) {
          dump[table] = await db.query(table);
        }
      }
      final dir = await getDatabasesPath();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File(join(dir, 'backup_${reason}_$stamp.json'));
      await file.writeAsString(jsonEncode(dump));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _createMealsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesMeals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        portion_grams REAL NOT NULL DEFAULT 0,
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
      'portion_grams': meal.portionGrams,
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
    final startOfNextDay = start.add(const Duration(days: 1));
    final maps = await database.query(
      tablesMeals,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), startOfNextDay.toIso8601String()],
    );
    return maps.map(_mealFromMap).toList();
  }

  Meal _mealFromMap(Map<String, dynamic> m) => Meal(
        id: m['id'] as int?,
        name: m['name'] as String,
        portionGrams: (m['portion_grams'] as num?)?.toDouble() ?? 0,
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
    final startOfNextDay = start.add(const Duration(days: 1));
    final maps = await database.query(
      tablesExercises,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), startOfNextDay.toIso8601String()],
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
