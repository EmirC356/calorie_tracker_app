import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/index.dart';

class DatabaseService {
  static const String _dbName = 'calorie_tracker.db';
  static const int _dbVersion = 7;

  /// Current local schema version (for backup metadata).
  static int get currentSchemaVersion => _dbVersion;

  static const String tablesMeals = 'meals';
  static const String tablesExercises = 'exercises';
  static const String tablesMealPreps = 'meal_preps';
  static const String tablesWeightEntries = 'weight_entries';
  static const String tablesGoals = 'goals';
  static const String tablesGoalOccurrences = 'goal_occurrences';
  static const String tablesGoalSuggestions = 'goal_suggestions';
  static const String tablesWaterEntries = 'water_entries';
  static const String tablesPauseHistory = 'pause_history';

  /// Optional override for the database file path. When null (production) the
  /// default app database path is used. Tests inject a temp/in-memory path.
  final String? overridePath;

  DatabaseService({this.overridePath});

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = overridePath ?? join(await getDatabasesPath(), _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Enables foreign-key enforcement so the goal_occurrences → goals
  /// `ON DELETE CASCADE` actually fires. sqflite leaves FKs off by default;
  /// there were no FK constraints before v5, so enabling this is a no-op for
  /// the existing tables.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createMealsTable(db);
    await _createExercisesTable(db);
    await _createMealPrepsTable(db);
    await _createWeightEntriesTable(db);
    await _createTimestampIndexes(db);
    await _createGoalsTable(db);
    await _createGoalOccurrencesTable(db);
    await _createGoalSuggestionsTable(db);
    await _createWaterEntriesTable(db);
    await _createPauseHistoryTable(db);
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
    if (oldVersion < 5) {
      // Goals & Calendar feature. Purely additive — three brand-new tables, no
      // existing rows touched, so no backup is required.
      await _createGoalsTable(db);
      await _createGoalOccurrencesTable(db);
      await _createGoalSuggestionsTable(db);
    }
    if (oldVersion < 6) {
      // Water tracking — one new additive table.
      await _createWaterEntriesTable(db);
    }
    if (oldVersion < 7) {
      // Squad pause/vacation personal records — additive.
      await _createPauseHistoryTable(db);
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
        tablesGoals,
        tablesGoalOccurrences,
        tablesGoalSuggestions,
        tablesWaterEntries,
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

  // ─── Goals & Calendar tables (schema v5) ────────────────────────────────────

  Future<void> _createGoalsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesGoals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        custom_category_label TEXT,
        color_argb INTEGER NOT NULL,
        priority TEXT NOT NULL,
        type TEXT NOT NULL,
        metric TEXT,
        comparator TEXT,
        target REAL,
        period TEXT,
        min_duration_min INTEGER,
        start_date TEXT NOT NULL,
        time_of_day TEXT,
        recurrence_json TEXT NOT NULL,
        end_date_days_from_start INTEGER,
        squad_visible INTEGER NOT NULL DEFAULT 0,
        reminder_minutes_before INTEGER,
        morning_brief_included INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_goals_start_date ON $tablesGoals(start_date)');
    await db.execute(
        'CREATE INDEX idx_goals_archived ON $tablesGoals(archived)');
  }

  Future<void> _createGoalOccurrencesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesGoalOccurrences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        occurrence_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        done_at TEXT,
        override_flag INTEGER NOT NULL DEFAULT 0,
        period_value_cached REAL,
        notes TEXT,
        UNIQUE(goal_id, occurrence_date),
        FOREIGN KEY(goal_id) REFERENCES $tablesGoals(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_occurrences_date ON $tablesGoalOccurrences(occurrence_date)');
    await db.execute(
        'CREATE INDEX idx_occurrences_status ON $tablesGoalOccurrences(status)');
    await db.execute(
        'CREATE INDEX idx_occurrences_goal ON $tablesGoalOccurrences(goal_id)');
  }

  Future<void> _createPauseHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesPauseHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        squad_id TEXT NOT NULL,
        until TEXT NOT NULL,
        reason TEXT,
        days INTEGER NOT NULL,
        declared_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createWaterEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesWaterEntries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_ml INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_water_timestamp ON $tablesWaterEntries(timestamp)');
  }

  Future<void> _createGoalSuggestionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablesGoalSuggestions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_uid TEXT NOT NULL,
        from_name TEXT NOT NULL,
        squad_id TEXT NOT NULL,
        suggested_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        payload_json TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_suggestions_status ON $tablesGoalSuggestions(status)');
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

  /// Meals with `timestamp` in [start, endExclusive). Timestamps are stored as
  /// local naive ISO strings, so lexicographic comparison is chronological.
  Future<List<Meal>> getMealsInRange(
      DateTime start, DateTime endExclusive) async {
    final database = await db;
    final maps = await database.query(
      tablesMeals,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), endExclusive.toIso8601String()],
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

  Future<int> updateMeal(Meal meal) async {
    final database = await db;
    return await database.update(
      tablesMeals,
      {
        'name': meal.name,
        'portion_grams': meal.portionGrams,
        'nutrients': jsonEncode(meal.nutrients.toJson()),
        'timestamp': meal.timestamp.toIso8601String(),
        'notes': meal.notes,
      },
      where: 'id = ?',
      whereArgs: [meal.id],
    );
  }

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

  /// Exercises with `timestamp` in [start, endExclusive).
  Future<List<Exercise>> getExercisesInRange(
      DateTime start, DateTime endExclusive) async {
    final database = await db;
    final maps = await database.query(
      tablesExercises,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), endExclusive.toIso8601String()],
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

  Future<int> updateExercise(Exercise exercise) async {
    final database = await db;
    return await database.update(
      tablesExercises,
      {
        'name': exercise.name,
        'durationMinutes': exercise.durationMinutes,
        'caloriesBurned': exercise.caloriesBurned,
        'timestamp': exercise.timestamp.toIso8601String(),
        'notes': exercise.notes,
        'intensity': exercise.intensity,
      },
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

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

  /// Weight entries with `timestamp` in [start, endExclusive), oldest first.
  Future<List<WeightEntry>> getWeightEntriesInRange(
      DateTime start, DateTime endExclusive) async {
    final database = await db;
    final maps = await database.query(
      tablesWeightEntries,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), endExclusive.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return maps.map(WeightEntry.fromJson).toList();
  }

  // ─── Water entry operations ─────────────────────────────────────────────────

  Future<int> insertWaterEntry(WaterEntry entry) async {
    final database = await db;
    return database.insert(tablesWaterEntries, entry.toMap());
  }

  Future<List<WaterEntry>> getWaterEntriesByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    return getWaterEntriesInRange(start, start.add(const Duration(days: 1)));
  }

  Future<List<WaterEntry>> getWaterEntriesInRange(
      DateTime start, DateTime endExclusive) async {
    final database = await db;
    final maps = await database.query(
      tablesWaterEntries,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.toIso8601String(), endExclusive.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return maps.map(WaterEntry.fromMap).toList();
  }

  Future<int> deleteWaterEntry(int id) async {
    final database = await db;
    return database.delete(tablesWaterEntries, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Pause history (personal records of squad pauses) ───────────────────────

  Future<int> insertPauseHistory({
    required String squadId,
    required DateTime until,
    String? reason,
    required int days,
    required DateTime declaredAt,
  }) async {
    final database = await db;
    return database.insert(tablesPauseHistory, {
      'squad_id': squadId,
      'until': ymd(until),
      'reason': reason,
      'days': days,
      'declared_at': declaredAt.toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPauseHistory() async {
    final database = await db;
    return database.query(tablesPauseHistory, orderBy: 'declared_at DESC');
  }

  Future<void> close() async {
    final database = await db;
    database.close();
  }
}
