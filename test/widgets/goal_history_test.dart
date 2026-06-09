import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/screens/calendar/goal_history_screen.dart';

Goal _goal() => Goal(
      title: 'Read 30 min',
      category: GoalCategory.personal,
      color: const Color(0xFFB57EDC),
      type: GoalType.manual,
      startDate: DateTime(2026, 6, 1),
      recurrence: const RecurrenceDaily(),
      createdAt: DateTime(2026, 6, 1),
    );

GoalHistoryEntry _entry(OccurrenceStatus s, int day, {bool edited = false}) =>
    GoalHistoryEntry(
      _goal(),
      GoalOccurrence(
        goalId: 1,
        occurrenceDate: DateTime(2026, 6, day),
        status: s,
        overrideFlag: edited,
      ),
    );

void main() {
  testWidgets('renders occurrences with mixed statuses + the success-rate card',
      (tester) async {
    final entries = [
      _entry(OccurrenceStatus.done, 3),
      _entry(OccurrenceStatus.failed, 2, edited: true),
      _entry(OccurrenceStatus.skipped, 1),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [GoalHistoryBody(entries: entries, onTap: (_) {})],
        ),
      ),
    ));

    expect(find.text('Read 30 min'), findsNWidgets(3));
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // done
    expect(find.byIcon(Icons.cancel), findsOneWidget); // failed
    expect(find.byIcon(Icons.remove_circle), findsOneWidget); // skipped
    expect(find.text('edited'), findsOneWidget); // override indicator
    expect(find.text('SUCCESS RATE BY CATEGORY'), findsOneWidget);
    expect(find.text('OCCURRENCES (3)'), findsOneWidget);
  });

  testWidgets('tapping a row fires onTap with the entry', (tester) async {
    GoalHistoryEntry? tapped;
    final entries = [_entry(OccurrenceStatus.done, 3)];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalHistoryBody(entries: entries, onTap: (e) => tapped = e),
      ),
    ));

    await tester.tap(find.text('Read 30 min'));
    expect(tapped, isNotNull);
    expect(tapped!.status, OccurrenceStatus.done);
  });

  testWidgets('empty entries show the no-match message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GoalHistoryBody(entries: const [], onTap: (_) {})),
    ));
    expect(find.text('No occurrences match these filters'), findsOneWidget);
  });
}
