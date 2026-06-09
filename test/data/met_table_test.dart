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

    test('table has sensible, positive MET values', () {
      expect(MetTable.activities, isNotEmpty);
      expect(MetTable.activities.every((a) => a.met > 0 && a.met < 25), isTrue);
    });
  });
}
