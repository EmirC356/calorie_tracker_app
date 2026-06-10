import 'package:flutter/material.dart';
import '../models/index.dart';
import '../providers/meal_provider.dart';
import '../providers/exercise_provider.dart';

/// Deletes [meal] and shows a 5s "UNDO" snackbar that re-adds it (a slipped tap
/// shouldn't lose data). Undo re-inserts the entry (a new row id is assigned).
///
/// [messenger] is captured by the caller before any navigation pop so the
/// snackbar survives a closing sheet. [afterChange] is awaited after the delete
/// and after an undo — pass a reload for screens that hold their own list.
Future<void> deleteMealWithUndo(
  ScaffoldMessengerState messenger,
  MealProvider provider,
  Meal meal, {
  Future<void> Function()? afterChange,
}) async {
  await provider.deleteMeal(meal.id!);
  await afterChange?.call();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Deleted "${meal.name}"', maxLines: 1, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () async {
          await provider.addMeal(meal);
          await afterChange?.call();
        },
      ),
    ));
}

/// Deletes [exercise] with a 5s "UNDO" snackbar that re-adds it.
Future<void> deleteExerciseWithUndo(
  ScaffoldMessengerState messenger,
  ExerciseProvider provider,
  Exercise exercise, {
  Future<void> Function()? afterChange,
}) async {
  await provider.deleteExercise(exercise.id!);
  await afterChange?.call();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Deleted "${exercise.name}"', maxLines: 1, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () async {
          await provider.addExercise(exercise);
          await afterChange?.call();
        },
      ),
    ));
}
