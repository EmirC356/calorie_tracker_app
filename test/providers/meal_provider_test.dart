import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/meal.dart';
import 'package:calorie_tracker_app/models/nutrient.dart';
import 'package:calorie_tracker_app/providers/meal_provider.dart';

Meal _meal(DateTime ts, double cal) => Meal(
      name: 'm',
      portionGrams: 0,
      timestamp: ts,
      nutrients: NutrientInfo(
        calories: cal, protein: 0, carbohydrates: 0, fat: 0, fiber: 0, sugar: 0),
    );

void main() {
  group('bucketDailyCalories', () {
    final now = DateTime(2026, 6, 8, 15, 0);

    test('returns one zero-filled bucket per day, oldest first', () {
      final result = MealProvider.bucketDailyCalories([], 14, now: now);
      expect(result.length, 14);
      expect(result.first.day.isBefore(result.last.day), isTrue);
      expect(result.every((d) => d.value == 0), isTrue);
      expect(result.last.day, DateTime(2026, 6, 8));
    });

    test('sums calories into the correct day bucket', () {
      final meals = [
        _meal(DateTime(2026, 6, 8, 9), 300),
        _meal(DateTime(2026, 6, 8, 20), 500),
        _meal(DateTime(2026, 6, 7, 12), 250),
      ];
      final result = MealProvider.bucketDailyCalories(meals, 14, now: now);
      final byDay = {for (final d in result) d.day: d.value};
      expect(byDay[DateTime(2026, 6, 8)], 800);
      expect(byDay[DateTime(2026, 6, 7)], 250);
      expect(byDay[DateTime(2026, 6, 6)], 0);
    });

    test('ignores meals outside the window', () {
      final meals = [_meal(DateTime(2026, 5, 1), 999)];
      final result = MealProvider.bucketDailyCalories(meals, 14, now: now);
      expect(result.fold<double>(0, (s, d) => s + d.value), 0);
    });
  });
}
