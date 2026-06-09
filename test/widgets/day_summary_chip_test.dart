import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/calendar/day_summary_chip.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));

void main() {
  testWidgets('renders its text', (tester) async {
    await _pump(tester,
        const DaySummaryChip(icon: Icons.restaurant, text: '4 meals · 1820 kcal', color: kCyan));
    expect(find.text('4 meals · 1820 kcal'), findsOneWidget);
  });

  testWidgets('forActivity builds meal, exercise and weight chips', (tester) async {
    const a = DayActivity(
      mealCount: 4,
      calories: 1820,
      exerciseCount: 1,
      exerciseMinutes: 30,
      hasWeight: true,
      weightKg: 74.5,
    );
    await _pump(tester, Column(children: DaySummaryChip.forActivity(a)));
    expect(find.textContaining('4 meals · 1820 kcal'), findsOneWidget);
    expect(find.textContaining('1 ex · 30 min'), findsOneWidget);
    expect(find.textContaining('74.5 kg'), findsOneWidget);
  });

  testWidgets('forActivity omits chips for zero activity', (tester) async {
    const a = DayActivity(mealCount: 0, exerciseCount: 0, hasWeight: false);
    final chips = DaySummaryChip.forActivity(a);
    expect(chips, isEmpty);
  });
}
