import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/squad_goal.dart';
import 'package:calorie_tracker_app/widgets/squad/goal_summary.dart';

Widget _wrap(SquadGoal goal) =>
    MaterialApp(home: Scaffold(body: GoalSummary(goal: goal)));

void main() {
  group('GoalSummary widget', () {
    testWidgets('renders a combined goal', (tester) async {
      await tester.pumpWidget(_wrap(
        const SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2200, exerciseMinutesMin: 30),
      ));
      expect(find.text('≤ 2200 kcal & ≥ 30 min'), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('renders the unset state', (tester) async {
      await tester.pumpWidget(_wrap(const SquadGoal()));
      expect(find.text('No goal set'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });
  });
}
