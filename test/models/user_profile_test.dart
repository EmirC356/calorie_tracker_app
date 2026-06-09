import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/user_profile.dart';

void main() {
  group('UserProfile Mifflin-St Jeor', () {
    const male = UserProfile(
      heightCm: 180,
      age: 25,
      sex: Sex.male,
      activity: ActivityLevel.moderate,
      goal: Goal.maintain,
    );

    test('BMR matches the Mifflin-St Jeor formula for a male', () {
      // 10*80 + 6.25*180 - 5*25 + 5 = 800 + 1125 - 125 + 5 = 1805
      expect(male.bmr(80), closeTo(1805, 0.001));
    });

    test('BMR uses the -161 constant for a female', () {
      const female = UserProfile(
        heightCm: 165,
        age: 30,
        sex: Sex.female,
        activity: ActivityLevel.sedentary,
        goal: Goal.maintain,
      );
      // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
      expect(female.bmr(60), closeTo(1320.25, 0.001));
    });

    test('TDEE applies the activity factor', () {
      expect(male.tdee(80), closeTo(1805 * 1.55, 0.001));
    });

    test('calorie target shifts by goal', () {
      final maintain = male.tdee(80);
      expect(male.copyWith(goal: Goal.maintain).calorieTarget(80), closeTo(maintain, 0.001));
      expect(male.copyWith(goal: Goal.cut).calorieTarget(80), closeTo(maintain - 500, 0.001));
      expect(male.copyWith(goal: Goal.bulk).calorieTarget(80), closeTo(maintain + 300, 0.001));
    });

    test('protein target uses goal-based g/kg within range', () {
      expect(male.copyWith(goal: Goal.cut).proteinTargetGrams(80), closeTo(80 * 2.2, 0.001));
      expect(male.copyWith(goal: Goal.maintain).proteinTargetGrams(80), closeTo(80 * 1.6, 0.001));
      expect(male.copyWith(goal: Goal.bulk).proteinTargetGrams(80), closeTo(80 * 2.0, 0.001));
    });

    test('round-trips through JSON', () {
      final restored = UserProfile.fromJson(male.copyWith(fallbackWeightKg: 82.5).toJson());
      expect(restored.heightCm, 180);
      expect(restored.age, 25);
      expect(restored.sex, Sex.male);
      expect(restored.activity, ActivityLevel.moderate);
      expect(restored.goal, Goal.maintain);
      expect(restored.fallbackWeightKg, 82.5);
    });
  });
}
