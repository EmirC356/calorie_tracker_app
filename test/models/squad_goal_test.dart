import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/squad_goal.dart';

void main() {
  group('SquadGoal.evaluate', () {
    GoalStatus eval(SquadGoal g, {double consumed = 0, int ex = 0, double burned = 0, bool over = false}) =>
        g.evaluate(consumed: consumed, exerciseMinutes: ex, burned: burned, dayOver: over);

    test('calorie cap: at/under target hits, over is inProgress then missed', () {
      const g = SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2200);
      expect(eval(g, consumed: 2000), GoalStatus.hit);
      expect(eval(g, consumed: 2200), GoalStatus.hit);
      expect(eval(g, consumed: 2400), GoalStatus.inProgress);
      expect(eval(g, consumed: 2400, over: true), GoalStatus.missed);
    });

    test('calorie floor: at/over target hits', () {
      const g = SquadGoal(calorieMode: CalorieMode.floor, calorieTarget: 1800);
      expect(eval(g, consumed: 1900), GoalStatus.hit);
      expect(eval(g, consumed: 1700), GoalStatus.inProgress);
      expect(eval(g, consumed: 1700, over: true), GoalStatus.missed);
    });

    test('min exercise minutes', () {
      const g = SquadGoal(exerciseMinutesMin: 30);
      expect(eval(g, ex: 30), GoalStatus.hit);
      expect(eval(g, ex: 20), GoalStatus.inProgress);
      expect(eval(g, ex: 20, over: true), GoalStatus.missed);
    });

    test('min calories burned', () {
      const g = SquadGoal(caloriesBurnedMin: 400);
      expect(eval(g, burned: 450), GoalStatus.hit);
      expect(eval(g, burned: 300, over: true), GoalStatus.missed);
    });

    test('combined goal hits only when ALL sub-goals pass', () {
      const g = SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2200, exerciseMinutesMin: 30);
      expect(eval(g, consumed: 2000, ex: 35), GoalStatus.hit);
      expect(eval(g, consumed: 2000, ex: 10), GoalStatus.inProgress); // exercise fails
      expect(eval(g, consumed: 2500, ex: 35, over: true), GoalStatus.missed); // calories fail
    });

    test('empty goal is never hit', () {
      const g = SquadGoal();
      expect(eval(g), GoalStatus.inProgress);
      expect(eval(g, over: true), GoalStatus.missed);
    });
  });

  group('SquadGoal.summary', () {
    test('formats each combination', () {
      expect(const SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2200).summary, '≤ 2200 kcal');
      expect(const SquadGoal(calorieMode: CalorieMode.floor, calorieTarget: 1800).summary, '≥ 1800 kcal');
      expect(const SquadGoal(exerciseMinutesMin: 30).summary, '≥ 30 min');
      expect(const SquadGoal(caloriesBurnedMin: 400).summary, '≥ 400 kcal burned');
      expect(
        const SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2200, exerciseMinutesMin: 30).summary,
        '≤ 2200 kcal & ≥ 30 min',
      );
      expect(const SquadGoal().summary, 'No goal set');
    });
  });
}
