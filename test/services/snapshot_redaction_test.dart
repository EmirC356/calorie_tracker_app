import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/meal.dart';
import 'package:calorie_tracker_app/models/exercise.dart';
import 'package:calorie_tracker_app/models/nutrient.dart';
import 'package:calorie_tracker_app/models/squad_goal.dart';
import 'package:calorie_tracker_app/models/squad_member.dart';
import 'package:calorie_tracker_app/services/snapshot_service.dart';

void main() {
  final stats = DayStats(
    consumed: 2000,
    burned: 300,
    exerciseMinutes: 40,
    meals: [
      Meal(name: 'Eggs', portionGrams: 0, timestamp: DateTime(2026, 6, 9, 8),
        nutrients: NutrientInfo(calories: 200, protein: 18, carbohydrates: 2, fat: 14, fiber: 0, sugar: 0)),
    ],
    exercises: [
      Exercise(name: 'Run', durationMinutes: 40, caloriesBurned: 300, timestamp: DateTime(2026, 6, 9, 18)),
    ],
  );

  Map<String, dynamic> build(SharingLevel level) => SnapshotService.buildEntry(
        status: GoalStatus.inProgress, stats: stats, level: level, updatedAt: 'fixed');

  group('Snapshot redaction by sharing level', () {
    test("'status' shares only the status", () {
      final m = build(SharingLevel.status);
      expect(m['status'], 'inProgress');
      expect(m.containsKey('consumed'), isFalse);
      expect(m.containsKey('burned'), isFalse);
      expect(m.containsKey('exerciseMinutes'), isFalse);
      expect(m.containsKey('meals'), isFalse);
      expect(m.containsKey('exercises'), isFalse);
    });

    test("'totals' adds consumed/burned/exerciseMinutes but no detail lists", () {
      final m = build(SharingLevel.totals);
      expect(m['consumed'], 2000);
      expect(m['burned'], 300);
      expect(m['exerciseMinutes'], 40);
      expect(m.containsKey('meals'), isFalse);
      expect(m.containsKey('exercises'), isFalse);
    });

    test("'full' adds the meal and exercise lists", () {
      final m = build(SharingLevel.full);
      expect(m['consumed'], 2000);
      expect((m['meals'] as List).first['name'], 'Eggs');
      expect((m['meals'] as List).first['kcal'], 200);
      expect((m['exercises'] as List).first['minutes'], 40);
      expect((m['exercises'] as List).first['kcal'], 300);
    });

    test('dateKey uses local calendar date, zero-padded', () {
      expect(SnapshotService.dateKey(DateTime(2026, 6, 9, 1, 0)), '2026-06-09');
      expect(SnapshotService.dateKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    });
  });
}
