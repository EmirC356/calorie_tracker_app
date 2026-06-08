import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/database_service.dart';

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

  Future<void> deleteMeal(int id) async {
    await _dbService.deleteMeal(id);
    await loadMeals();
    await loadTodaysMeals();
  }

  Future<List<Meal>> getMealsByDate(DateTime date) async {
    return await _dbService.getMealsByDate(date);
  }
}
