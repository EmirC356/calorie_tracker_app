import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/meal.dart';
import 'package:calorie_tracker_app/models/nutrient.dart';

void main() {
  group('Meal serialization', () {
    final nutrients = NutrientInfo(
      calories: 500,
      protein: 30,
      carbohydrates: 45,
      fat: 18,
      fiber: 6,
      sugar: 4,
    );

    test('round-trips portionGrams through toJson/fromJson', () {
      final meal = Meal(
        name: 'Chicken & rice',
        portionGrams: 320,
        nutrients: nutrients,
        timestamp: DateTime(2026, 6, 8, 12, 30),
      );

      final restored = Meal.fromJson(meal.toJson());

      expect(restored.name, 'Chicken & rice');
      expect(restored.portionGrams, 320);
      expect(restored.nutrients.calories, 500);
      expect(restored.timestamp, DateTime(2026, 6, 8, 12, 30));
    });

    test('imports the legacy "weight" key as portionGrams', () {
      final legacy = {
        'name': 'Old export',
        'weight': 250.0,
        'nutrients': nutrients.toJson(),
        'timestamp': '2026-01-01T08:00:00.000',
      };

      final meal = Meal.fromJson(legacy);

      expect(meal.portionGrams, 250.0);
    });

    test('defaults portionGrams to 0 when absent', () {
      final meal = Meal.fromJson({
        'name': 'No portion',
        'nutrients': nutrients.toJson(),
        'timestamp': '2026-01-01T08:00:00.000',
      });

      expect(meal.portionGrams, 0);
    });
  });
}
