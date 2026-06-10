import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/providers/goal_provider.dart';
import 'package:calorie_tracker_app/widgets/calendar/goal_action_dialog.dart';

void main() {
  testWidgets('opens a centered Dialog (not a bottom sheet) with the five actions',
      (tester) async {
    final goal = Goal(
      id: 1,
      title: 'Read 30 min',
      category: GoalCategory.personal,
      color: const Color(0xFFB57EDC),
      type: GoalType.manual, // non-tracked → no async progress
      startDate: DateTime(2026, 6, 9),
      recurrence: const RecurrenceNone(),
      createdAt: DateTime(2026, 6, 1),
    );

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: GoalProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () =>
                  showGoalActionDialog(ctx, goal: goal, date: DateTime(2026, 6, 9)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Read 30 min'), findsOneWidget);
    for (final label in ['Edit', 'Mark done', 'Mark failed', 'Skip', 'Delete']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
