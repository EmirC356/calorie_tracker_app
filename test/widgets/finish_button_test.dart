import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/widgets/calendar/day_goal_row.dart';

void main() {
  Goal manual({GoalType type = GoalType.manual}) => Goal(
        title: 'Read 30 min',
        category: GoalCategory.health,
        color: const Color(0xFF22C55E),
        startDate: DateTime(2026, 6, 12),
        createdAt: DateTime(2026, 6, 1),
        type: type,
      );

  Future<void> pumpRow(WidgetTester tester, DayGoalRow row) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: row)));

  testWidgets('Finish shows on an open goal when onFinish is provided', (tester) async {
    await pumpRow(tester,
        DayGoalRow(goal: manual(), status: OccurrenceStatus.open, onFinish: () {}));
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('no Finish on a done goal; Undo shows when onUndo provided', (tester) async {
    await pumpRow(tester, DayGoalRow(
        goal: manual(), status: OccurrenceStatus.done, onFinish: () {}, onUndo: () {}));
    expect(find.text('Finish'), findsNothing); // status != open
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('no Finish/Undo when callbacks are null (e.g. tracked / future)', (tester) async {
    await pumpRow(tester, DayGoalRow(goal: manual(), status: OccurrenceStatus.open));
    expect(find.text('Finish'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('tapping Finish fires the callback', (tester) async {
    var tapped = false;
    await pumpRow(tester, DayGoalRow(
        goal: manual(), status: OccurrenceStatus.open, onFinish: () => tapped = true));
    await tester.tap(find.text('Finish'));
    expect(tapped, isTrue);
  });
}
