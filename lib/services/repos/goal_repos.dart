import '../../models/index.dart';
import '../database_service.dart';

/// Narrow, read-only "ports" the GoalEvaluator depends on. Each exposes only
/// the slice of app data a tracked metric needs over a half-open [start, end)
/// window. Keeping these abstract lets the evaluator be unit-tested with simple
/// in-memory fakes, and keeps it independent of sqflite.

abstract class MealRepo {
  Future<List<Meal>> mealsInRange(DateTime start, DateTime endExclusive);
}

abstract class ExerciseRepo {
  Future<List<Exercise>> exercisesInRange(DateTime start, DateTime endExclusive);
}

abstract class WeightRepo {
  Future<List<WeightEntry>> weightEntriesInRange(
      DateTime start, DateTime endExclusive);
}

/// Water tracking is a known future feature. The port exists so the evaluator
/// can compile against it; until water logging ships, callers pass `null` and
/// the evaluator never auto-fails a water goal.
abstract class WaterRepo {
  Future<double> waterMlInRange(DateTime start, DateTime endExclusive);
}

// ─── DatabaseService-backed implementations ──────────────────────────────────

class DbMealRepo implements MealRepo {
  final DatabaseService _db;
  const DbMealRepo(this._db);
  @override
  Future<List<Meal>> mealsInRange(DateTime start, DateTime endExclusive) =>
      _db.getMealsInRange(start, endExclusive);
}

class DbExerciseRepo implements ExerciseRepo {
  final DatabaseService _db;
  const DbExerciseRepo(this._db);
  @override
  Future<List<Exercise>> exercisesInRange(
          DateTime start, DateTime endExclusive) =>
      _db.getExercisesInRange(start, endExclusive);
}

class DbWeightRepo implements WeightRepo {
  final DatabaseService _db;
  const DbWeightRepo(this._db);
  @override
  Future<List<WeightEntry>> weightEntriesInRange(
          DateTime start, DateTime endExclusive) =>
      _db.getWeightEntriesInRange(start, endExclusive);
}
