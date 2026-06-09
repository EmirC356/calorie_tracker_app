import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/widgets/calendar/goal_chip.dart';

Goal _goal() => Goal(
      title: 'Read 30 min',
      category: GoalCategory.personal,
      color: const Color(0xFFB57EDC),
      priority: GoalPriority.high,
      startDate: DateTime(2026, 6, 9),
      recurrence: const RecurrenceNone(),
      createdAt: DateTime(2026, 6, 1),
    );

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));

void main() {
  testWidgets('renders the title and the done status icon', (tester) async {
    await _pump(tester, GoalChip(goal: _goal(), status: OccurrenceStatus.done));
    expect(find.text('Read 30 min'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('shows the failed icon for a failed occurrence', (tester) async {
    await _pump(tester, GoalChip(goal: _goal(), status: OccurrenceStatus.failed));
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('compact mode hides the title but keeps the status icon', (tester) async {
    await _pump(tester, GoalChip(goal: _goal(), status: OccurrenceStatus.open, compact: true));
    expect(find.text('Read 30 min'), findsNothing);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('tap fires onTap', (tester) async {
    var tapped = false;
    await _pump(tester,
        GoalChip(goal: _goal(), status: OccurrenceStatus.open, onTap: () => tapped = true));
    await tester.tap(find.byType(GoalChip));
    expect(tapped, isTrue);
  });
}
