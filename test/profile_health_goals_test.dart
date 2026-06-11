import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  group('serialization', () {
    test('UserProfile round-trips the health-goal fields', () {
      const p = UserProfile(
        heightCm: 180, age: 30, sex: Sex.male, activity: ActivityLevel.moderate, goal: DietGoal.cut,
        calorieGoalMode: CalorieMode.cap, calorieGoalTarget: 2100,
        weeklyExerciseSessions: 4, minSessionMinutes: 25, birthday: '1996-03-14',
      );
      final back = UserProfile.fromJson(p.toJson());
      expect(back.calorieGoalMode, CalorieMode.cap);
      expect(back.calorieGoalTarget, 2100);
      expect(back.weeklyExerciseSessions, 4);
      expect(back.minSessionMinutes, 25);
      expect(back.birthday, '1996-03-14');
    });

    test('legacy profile JSON (no health goals) defaults safely', () {
      final back = UserProfile.fromJson({
        'heightCm': 175, 'age': 28, 'sex': 'female', 'activity': 'light', 'goal': 'maintain',
      });
      expect(back.calorieGoalMode, CalorieMode.none);
      expect(back.calorieGoalTarget, isNull);
      expect(back.minSessionMinutes, 20);
      expect(back.hasHealthGoal, isFalse);
    });

    test('ProfileGoalSnapshot summaries + daily goal mapping', () {
      const s = ProfileGoalSnapshot(
        calorieMode: CalorieMode.cap, calorieTarget: 2200,
        weeklyExerciseSessions: 3, minSessionMinutes: 20,
      );
      expect(s.calorieSummary, '≤ 2200 kcal/day');
      expect(s.exerciseSummary, '3 sessions/week (≥ 20 min)');
      final daily = s.toDailyGoal();
      expect(daily.calorieMode, CalorieMode.cap);
      expect(daily.calorieTarget, 2200);
      expect(daily.exerciseMinutesMin, 20); // a session today satisfies the daily sub-goal
    });
  });

  group('TDEE suggestion math (Mifflin-St Jeor)', () {
    // 80kg, 180cm, 30y male, moderate: BMR = 10*80+6.25*180-5*30+5 = 1780; TDEE = *1.55 = 2759.
    const p = UserProfile(
        heightCm: 180, age: 30, sex: Sex.male, activity: ActivityLevel.moderate, goal: DietGoal.maintain);

    test('cut suggests TDEE − 500', () {
      final cut = p.copyWith(goal: DietGoal.cut);
      expect(cut.calorieTarget(80).round(), 2259);
      expect(cut.suggestedCalorieMode, CalorieMode.cap);
    });
    test('maintain suggests TDEE', () {
      expect(p.calorieTarget(80).round(), 2759);
      expect(p.suggestedCalorieMode, CalorieMode.cap);
    });
    test('bulk suggests TDEE + 300 and floors', () {
      final bulk = p.copyWith(goal: DietGoal.bulk);
      expect(bulk.calorieTarget(80).round(), 3059);
      expect(bulk.suggestedCalorieMode, CalorieMode.floor);
    });
  });

  group('effective goal resolution', () {
    test('inherited + non-empty snapshot uses the profile snapshot', () {
      const m = SquadMember(
        uid: 'u1', inheritedFromProfile: true,
        profileGoalSnapshot: ProfileGoalSnapshot(calorieMode: CalorieMode.cap, calorieTarget: 2000),
        goal: SquadGoal(calorieMode: CalorieMode.floor, calorieTarget: 3000),
      );
      expect(m.effectiveGoal.calorieMode, CalorieMode.cap);
      expect(m.effectiveGoal.calorieTarget, 2000);
    });
    test('override (inherited false) uses the explicit goal', () {
      const m = SquadMember(
        uid: 'u1', inheritedFromProfile: false,
        profileGoalSnapshot: ProfileGoalSnapshot(calorieMode: CalorieMode.cap, calorieTarget: 2000),
        goal: SquadGoal(calorieMode: CalorieMode.floor, calorieTarget: 3000),
      );
      expect(m.effectiveGoal.calorieMode, CalorieMode.floor);
      expect(m.effectiveGoal.calorieTarget, 3000);
    });
    test('inherited but empty snapshot falls back to the explicit goal (back-compat)', () {
      const m = SquadMember(
        uid: 'u1', inheritedFromProfile: true,
        goal: SquadGoal(exerciseMinutesMin: 30),
      );
      expect(m.effectiveGoal.exerciseMinutesMin, 30);
    });
  });

  test('syncProfileGoalsToAllSquads updates snapshot everywhere, goal only where inherited', () async {
    final fs = FakeFirebaseFirestore();
    final svc = SquadService(firestore: fs);
    // Two squads: s1 inherits, s2 overrides.
    await fs.doc('squads/s1').set({'name': 'A', 'ownerUid': 'u1', 'memberUids': ['u1'], 'inviteCode': '111111'});
    await fs.doc('squads/s2').set({'name': 'B', 'ownerUid': 'u1', 'memberUids': ['u1'], 'inviteCode': '222222'});
    await fs.doc('squads/s1/members/u1').set({'sharingLevel': 'status', 'inheritedFromProfile': true});
    await fs.doc('squads/s2/members/u1').set({
      'sharingLevel': 'status', 'inheritedFromProfile': false,
      'goal': {'calorieMode': 'floor', 'calorieTarget': 3000},
    });

    const snap = ProfileGoalSnapshot(calorieMode: CalorieMode.cap, calorieTarget: 1900, weeklyExerciseSessions: 3);
    await svc.syncProfileGoalsToAllSquads('u1', snap);

    final m1 = (await fs.doc('squads/s1/members/u1').get()).data()!;
    expect(m1['profileGoalSnapshot']['calorieTarget'], 1900);
    expect(m1['goal']['calorieMode'], 'cap'); // inherited → goal materialized
    expect(m1['goal']['calorieTarget'], 1900);

    final m2 = (await fs.doc('squads/s2/members/u1').get()).data()!;
    expect(m2['profileGoalSnapshot']['calorieTarget'], 1900); // snapshot still refreshed
    expect(m2['goal']['calorieMode'], 'floor'); // override untouched
    expect(m2['goal']['calorieTarget'], 3000);
  });
}
