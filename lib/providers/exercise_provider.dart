import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/database_service.dart';

class ExerciseProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<Exercise> _exercises = [];
  List<Exercise> _todaysExercises = [];

  List<Exercise> get exercises => _exercises;
  List<Exercise> get todaysExercises => _todaysExercises;

  double get todaysTotalCaloriesBurned =>
      _todaysExercises.fold(0, (sum, ex) => sum + ex.caloriesBurned);

  int get todaysTotalDuration =>
      _todaysExercises.fold(0, (sum, ex) => sum + ex.durationMinutes);

  Future<void> loadExercises() async {
    _exercises = await _dbService.getExercises();
    notifyListeners();
  }

  Future<void> loadTodaysExercises() async {
    final now = DateTime.now();
    _todaysExercises = await _dbService.getExercisesByDate(now);
    notifyListeners();
  }

  Future<void> addExercise(Exercise exercise) async {
    await _dbService.insertExercise(exercise);
    await loadExercises();
    await loadTodaysExercises();
  }

  Future<void> updateExercise(Exercise exercise) async {
    await _dbService.updateExercise(exercise);
    await loadExercises();
    await loadTodaysExercises();
  }

  Future<void> deleteExercise(int id) async {
    await _dbService.deleteExercise(id);
    await loadExercises();
    await loadTodaysExercises();
  }

  Future<List<Exercise>> getExercisesByDate(DateTime date) async {
    return await _dbService.getExercisesByDate(date);
  }
}
