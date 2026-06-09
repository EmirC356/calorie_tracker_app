import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/screens/calendar/goal_form_screen.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GoalFormScreen(onSubmit: (g) async {}),
    ));
  }

  // Scrolls [label] fully into view and taps it.
  Future<void> tapText(WidgetTester tester, String label) async {
    final f = find.text(label);
    await tester.scrollUntilVisible(f, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('selecting Weekly reveals the day-specific picker by default',
      (tester) async {
    await pumpForm(tester);
    await tapText(tester, 'Weekly');
    expect(find.text('Specific days'), findsOneWidget);
    expect(find.text('N / week'), findsOneWidget);
  });

  testWidgets('switching to "N / week" shows the times-per-week stepper',
      (tester) async {
    await pumpForm(tester);
    await tapText(tester, 'Weekly');
    await tapText(tester, 'N / week');
    expect(find.text('Times per week'), findsOneWidget);
  });

  testWidgets('selecting Monthly reveals the day-of-month stepper', (tester) async {
    await pumpForm(tester);
    await tapText(tester, 'Monthly');
    expect(find.text('Day of month (1–28)'), findsOneWidget);
  });
}
