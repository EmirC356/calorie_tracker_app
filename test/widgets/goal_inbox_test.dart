import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/screens/squad/goal_inbox_screen.dart';

SquadGoalSuggestion suggestion({String fromName = 'Alex', String title = 'Gym 3x/week'}) {
  final goal = Goal(
    title: title,
    category: GoalCategory.health,
    color: const Color(0xFFF5A524),
    startDate: DateTime(2026, 6, 9),
    recurrence: const RecurrenceWeekly(nTimesPerWeek: 3),
    createdAt: DateTime(2026, 6, 1),
  );
  return SquadGoalSuggestion(
    id: 'sug1',
    squadId: 's1',
    fromUid: 'a',
    fromName: fromName,
    toUid: 'me',
    payloadJson: jsonEncode(goal.toJson()),
  );
}

Future<void> pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('renders the suggester, the proposed goal, and the actions', (tester) async {
    await pump(
      tester,
      GoalInboxList(
        suggestions: [suggestion()],
        onAccept: (_) {},
        onReject: (_) {},
        onDismiss: (_) {},
      ),
    );
    // Header renders in the uppercase caption style.
    expect(find.text('ALEX SUGGESTED A GOAL'), findsOneWidget);
    expect(find.text('Gym 3x/week'), findsOneWidget);
    expect(find.textContaining('3× per week'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('Accept / Reject / Dismiss fire their callbacks', (tester) async {
    SquadGoalSuggestion? accepted, rejected, dismissed;
    await pump(
      tester,
      GoalInboxList(
        suggestions: [suggestion()],
        onAccept: (s) => accepted = s,
        onReject: (s) => rejected = s,
        onDismiss: (s) => dismissed = s,
      ),
    );
    await tester.tap(find.text('Accept'));
    expect(accepted?.id, 'sug1');
    await tester.tap(find.text('Reject'));
    expect(rejected?.id, 'sug1');
    await tester.tap(find.text('Dismiss'));
    expect(dismissed?.id, 'sug1');
  });

  testWidgets('empty inbox shows the no-suggestions message', (tester) async {
    await pump(
      tester,
      GoalInboxList(suggestions: const [], onAccept: (_) {}, onReject: (_) {}, onDismiss: (_) {}),
    );
    expect(find.text('No goal suggestions right now.'), findsOneWidget);
  });
}
