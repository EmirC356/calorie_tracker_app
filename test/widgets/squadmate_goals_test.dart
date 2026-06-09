import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/widgets/squad/squadmate_goals.dart';

GoalVisible gv(String date, String status, {String title = 'Read 30 min', String? summary}) =>
    GoalVisible(
      id: '$title-$date',
      ownerUid: 'u',
      goalTitle: title,
      category: 'Personal',
      colorArgb: 0xFFB57EDC,
      priority: 'high',
      date: date,
      status: status,
      metricSummary: summary,
    );

Future<void> pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [child]))));

void main() {
  final today = DateTime(2026, 6, 10);

  testWidgets('SquadmateGoalsToday shows only today\'s goals with statuses', (tester) async {
    await pump(
      tester,
      SquadmateGoalsToday(
        asOf: today,
        goals: [
          gv('2026-06-10', 'done', title: 'Read 30 min'),
          gv('2026-06-10', 'failed', title: 'Gym session', summary: '0/1 sessions'),
          gv('2026-06-09', 'done', title: 'Yesterday goal'), // not today
        ],
      ),
    );
    expect(find.text('Read 30 min'), findsOneWidget);
    expect(find.text('Gym session'), findsOneWidget);
    expect(find.text('Yesterday goal'), findsNothing);
    expect(find.text('0/1 sessions'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // done
    expect(find.byIcon(Icons.cancel), findsOneWidget); // failed
  });

  testWidgets('SquadmateGoalsToday shows an empty message when nothing today', (tester) async {
    await pump(tester, SquadmateGoalsToday(asOf: today, goals: [gv('2026-06-01', 'done')]));
    expect(find.text('No goals shared for today.'), findsOneWidget);
  });

  testWidgets('SquadmateGoalStats renders hit rate + streak', (tester) async {
    await pump(
      tester,
      SquadmateGoalStats(asOf: today, goals: [
        gv('2026-06-10', 'done'),
        gv('2026-06-09', 'done'),
        gv('2026-06-08', 'failed'),
      ]),
    );
    expect(find.text('WEEKLY GOAL STATS'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget); // 2/3
  });
}
