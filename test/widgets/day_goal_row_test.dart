import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/widgets/calendar/day_goal_row.dart';

Goal goal({int? reminder}) => Goal(
      title: 'Read 30 min',
      category: GoalCategory.personal,
      color: const Color(0xFFB57EDC),
      priority: GoalPriority.high,
      startDate: DateTime(2026, 6, 9),
      recurrence: const RecurrenceDaily(),
      reminderMinutesBefore: reminder,
      timeOfDay: reminder == null ? null : const TimeOfDay(hour: 8, minute: 0),
      createdAt: DateTime(2026, 6, 1),
    );

Future<void> pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('row is at least 72dp tall and shows title + status', (tester) async {
    await pump(tester, DayGoalRow(goal: goal(), status: OccurrenceStatus.open));
    expect(find.text('Read 30 min'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget); // open status

    final material =
        find.descendant(of: find.byType(DayGoalRow), matching: find.byType(Material)).first;
    expect(tester.getSize(material).height, greaterThanOrEqualTo(kDayGoalRowMinHeight));
  });

  testWidgets('shows the reminder bell only when a reminder is set', (tester) async {
    await pump(tester, DayGoalRow(goal: goal(reminder: 30), status: OccurrenceStatus.open));
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
  });

  testWidgets('no reminder → no bell', (tester) async {
    await pump(tester, DayGoalRow(goal: goal(), status: OccurrenceStatus.done));
    expect(find.byIcon(Icons.notifications_active), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // done status
  });
}
