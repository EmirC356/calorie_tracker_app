import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/data/met_table.dart';

void main() {
  group('MetTable.caloriesBurned', () {
    test('kcal = MET * weightKg * hours', () {
      // 8 MET, 70 kg, 30 min (0.5 h) = 8 * 70 * 0.5 = 280
      expect(
        MetTable.caloriesBurned(met: 8, weightKg: 70, minutes: 30),
        closeTo(280, 0.001),
      );
    });

    test('scales linearly with duration', () {
      final thirty = MetTable.caloriesBurned(met: 6, weightKg: 80, minutes: 30);
      final sixty = MetTable.caloriesBurned(met: 6, weightKg: 80, minutes: 60);
      expect(sixty, closeTo(thirty * 2, 0.001));
    });

    test('intensity scales the estimate (low<medium<high)', () {
      final med = MetTable.caloriesBurned(met: 8, weightKg: 70, minutes: 30);
      final low = MetTable.caloriesBurned(met: 8, weightKg: 70, minutes: 30, intensity: 'low');
      final high = MetTable.caloriesBurned(met: 8, weightKg: 70, minutes: 30, intensity: 'high');
      expect(med, closeTo(280, 0.001));
      expect(low, closeTo(280 * 0.85, 0.001));
      expect(high, closeTo(280 * 1.2, 0.001));
      expect(MetTable.intensityFactor('medium'), 1.0);
    });

    test('table has sensible, positive MET values', () {
      expect(MetTable.activities, isNotEmpty);
      expect(MetTable.activities.every((a) => a.met > 0 && a.met < 25), isTrue);
    });
  });
}
