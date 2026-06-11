import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/screens/calendar/goal_form_screen.dart';

void main() {
  testWidgets('advanced fields are hidden until the chevron is tapped',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: GoalFormScreen(onSubmit: (_) async {})));

    // Simple zone shows Title / Color / Recurrence, but not the advanced
    // fields. Field labels render in the uppercase caption style.
    expect(find.text('COLOR'), findsOneWidget);
    expect(find.text('RECURRENCE'), findsOneWidget);
    expect(find.text('PRIORITY'), findsNothing);
    expect(find.text('GOAL TYPE'), findsNothing);
    expect(find.text('More options'), findsOneWidget);

    // Expand.
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Fewer options'), findsOneWidget);
    expect(find.text('PRIORITY'), findsOneWidget);
    expect(find.text('GOAL TYPE'), findsOneWidget);

    // Collapse again.
    await tester.tap(find.text('Fewer options'));
    await tester.pumpAndSettle();
    expect(find.text('PRIORITY'), findsNothing);
  });

  testWidgets('saving with only the simple fields applies the documented defaults',
      (tester) async {
    Goal? saved;
    await tester.pumpWidget(MaterialApp(
      home: GoalFormScreen(submitLabel: 'CREATE', onSubmit: (g) async => saved = g),
    ));

    await tester.enterText(find.byType(TextField).first, 'Drink water');
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, 'Drink water');
    expect(saved!.description, isNull);
    expect(saved!.category, GoalCategory.health); // inferred from the default amber
    expect(saved!.priority, GoalPriority.medium);
    expect(saved!.type, GoalType.manual);
    expect(saved!.recurrence, isA<RecurrenceNone>());
    expect(saved!.endDateDaysFromStart, isNull); // forever
    expect(saved!.timeOfDay, isNull);
    expect(saved!.reminderMinutesBefore, isNull);
    expect(saved!.morningBriefIncluded, isTrue);
    expect(saved!.squadVisible, isTrue); // create-form default flipped ON
    expect(saved!.startDate, dateOnly(saved!.createdAt));
  });
}
