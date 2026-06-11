import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:calorie_tracker_app/screens/calendar/goal_create_screen.dart';

void main() {
  String fmt(DateTime d) => DateFormat('EEE, MMM d, yyyy').format(DateTime(d.year, d.month, d.day));

  testWidgets('GoalCreateScreen pre-fills the start date from defaultStartDate', (tester) async {
    final viewed = DateTime(2026, 6, 20); // future → no backdate warning
    await tester.pumpWidget(MaterialApp(home: GoalCreateScreen(defaultStartDate: viewed)));
    await tester.pump();
    expect(find.text(fmt(viewed)), findsOneWidget);
  });

  testWidgets('GoalCreateScreen defaults to today when no date is given', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GoalCreateScreen()));
    await tester.pump();
    expect(find.text(fmt(DateTime.now())), findsOneWidget);
  });
}
