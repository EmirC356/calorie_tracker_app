import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/database_service.dart';

/// A single calendar day's aggregated value (used by the calories chart).
class DayTotal {
  final DateTime day;
  final double value;
  const DayTotal(this.day, this.value);
}

class MealProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<Meal> _meals = [];
  List<Meal> _todaysMeals = [];

  List<Meal> get meals => _meals;
  List<Meal> get todaysMeals => _todaysMeals;

  double get todaysTotalCalories =>
      _todaysMeals.fold(0, (sum, meal) => sum + meal.nutrients.calories);

  double get todaysTotalProtein =>
      _todaysMeals.fold(0, (sum, meal) => sum + meal.nutrients.protein);

  double get todaysTotalCarbs =>
      _todaysMeals.fold(0, (sum, meal) => sum + meal.nutrients.carbohydrates);

  double get todaysTotalFat =>
      _todaysMeals.fold(0, (sum, meal) => sum + meal.nutrients.fat);

  Future<void> loadMeals() async {
    _meals = await _dbService.getMeals();
    notifyListeners();
  }

  Future<void> loadTodaysMeals() async {
    final now = DateTime.now();
    _todaysMeals = await _dbService.getMealsByDate(now);
    notifyListeners();
  }

  Future<void> addMeal(Meal meal) async {
    await _dbService.insertMeal(meal);
    await loadMeals();
    await loadTodaysMeals();
  }

  Future<void> updateMeal(Meal meal) async {
    await _dbService.updateMeal(meal);
    await loadMeals();
    await loadTodaysMeals();
  }

  Future<void> deleteMeal(int id) async {
    await _dbService.deleteMeal(id);
    await loadMeals();
    await loadTodaysMeals();
  }

  Future<List<Meal>> getMealsByDate(DateTime date) async {
    return await _dbService.getMealsByDate(date);
  }

  /// Daily calorie totals for the last [days] days (oldest first), bucketed by
  /// calendar day from the loaded full meal list. Requires loadMeals() first.
  List<DayTotal> dailyCalories(int days, {DateTime? now}) =>
      bucketDailyCalories(_meals, days, now: now);

  /// Pure helper: buckets [meals] into per-day calorie totals for the last
  /// [days] days ending at [now] (defaults to today). Oldest day first, with
  /// zero-filled days for any with no meals. Extracted for unit testing.
  static List<DayTotal> bucketDailyCalories(List<Meal> meals, int days,
      {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final startDay =
        DateTime(ref.year, ref.month, ref.day).subtract(Duration(days: days - 1));
    final buckets = <DateTime, double>{};
    for (var i = 0; i < days; i++) {
      buckets[startDay.add(Duration(days: i))] = 0;
    }
    for (final m in meals) {
      final d = DateTime(m.timestamp.year, m.timestamp.month, m.timestamp.day);
      if (buckets.containsKey(d)) {
        buckets[d] = buckets[d]! + m.nutrients.calories;
      }
    }
    final entries = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => DayTotal(e.key, e.value)).toList();
  }
}
