import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:calorie_tracker_app/providers/goal_provider.dart';
import 'package:calorie_tracker_app/screens/calendar/calendar_week_view.dart';

void main() {
  testWidgets('shows a 3-day window and a left swipe shifts it forward by one day',
      (tester) async {
    // 2026-06-10 is a Wednesday → window Tue 9 / Wed 10 / Thu 11.
    final initial = DateTime(2026, 6, 10);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: GoalProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: CalendarWeekView(initialDate: initial, onTapDay: (_) {}),
        ),
      ),
    ));
    await tester.pump(); // run the post-frame activity load (guarded)

    expect(find.byType(PageView), findsOneWidget);
    // Header reflects the 3-day span (center ± 1 day).
    expect(find.textContaining('Tue 9'), findsWidgets);
    expect(find.textContaining('Thu 11 Jun'), findsWidgets);

    // Swipe left → window rolls forward by one day → Wed 10 / Thu 11 / Fri 12.
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wed 10'), findsWidgets);
    expect(find.textContaining('Fri 12 Jun'), findsWidgets);
    expect(find.textContaining('Tue 9'), findsNothing);
  });
}
