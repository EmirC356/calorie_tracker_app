import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/screens/calendar/goal_examples.dart';

void main() {
  test('provides 6 example templates with no id, anchored to today', () {
    final today = DateTime(2026, 6, 9);
    final examples = goalExamples(today);
    expect(examples, hasLength(6));
    for (final g in examples) {
      expect(g.id, isNull); // templates create new goals
      expect(g.startDate, dateOnly(today));
      expect(g.title, isNotEmpty);
      // Tracked examples carry a metric + target; manual ones don't.
      if (g.type == GoalType.tracked) {
        expect(g.metric, isNotNull);
        expect(g.target, isNotNull);
      }
      // Each example round-trips through the DB map shape.
      final back = Goal.fromMap(g.toMap());
      expect(back.title, g.title);
      expect(back.recurrence.toJson(), g.recurrence.toJson());
    }
  });

  test('includes the tracked kcal cap and the weekly gym example', () {
    final examples = goalExamples(DateTime(2026, 6, 9));
    final kcal = examples.firstWhere((g) => g.metric == TrackedMetric.kcalTotal);
    expect(kcal.comparator, Comparator.lessThanOrEqual);
    expect(kcal.target, 2200);

    final gym = examples.firstWhere((g) => g.metric == TrackedMetric.exerciseSessionCount);
    expect(gym.recurrence, isA<RecurrenceWeekly>());
    expect((gym.recurrence as RecurrenceWeekly).nTimesPerWeek, 3);
  });
}
