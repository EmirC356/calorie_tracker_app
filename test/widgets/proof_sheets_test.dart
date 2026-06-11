import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/models/squad.dart';
import 'package:calorie_tracker_app/models/photo.dart';
import 'package:calorie_tracker_app/widgets/squad/squad_picker_sheet.dart';
import 'package:calorie_tracker_app/widgets/squad/goal_attach_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpOpener(WidgetTester tester, Future<void> Function(BuildContext) onOpen) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(onPressed: () => onOpen(ctx), child: const Text('open')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('SquadPickerSheet persists the picked squad + returns its id', (tester) async {
    final squads = [
      Squad.fromMap('s1', {'name': 'Alpha', 'ownerUid': 'me', 'memberUids': ['me'], 'inviteCode': '111111'}),
      Squad.fromMap('s2', {'name': 'Bravo', 'ownerUid': 'me', 'memberUids': ['me'], 'inviteCode': '222222'}),
    ];
    String? returned;
    await pumpOpener(tester, (ctx) async {
      returned = await SquadPickerSheet.show(ctx, squads: squads, selectedId: 's1');
    });
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);

    await tester.tap(find.text('Bravo'));
    await tester.pumpAndSettle();

    expect(returned, 's2');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kProofLastSquadKey), 's2');
  });

  testWidgets('GoalAttachSheet lists goals + returns the tapped one', (tester) async {
    final goals = [
      const PhotoGoalRef(goalId: '1', occurrenceDate: '2026-06-11', title: 'Gym session', category: 'Fitness'),
      const PhotoGoalRef(goalId: '2', occurrenceDate: '2026-06-11', title: 'Read 30 min', category: 'Personal'),
    ];
    PhotoGoalRef? returned;
    await pumpOpener(tester, (ctx) async {
      returned = await GoalAttachSheet.show(ctx, goals: goals);
    });
    expect(find.text('Gym session'), findsOneWidget);
    expect(find.text('Read 30 min'), findsOneWidget);

    await tester.tap(find.text('Read 30 min'));
    await tester.pumpAndSettle();
    expect(returned?.goalId, '2');
  });

  testWidgets('GoalAttachSheet shows the empty state with no goals', (tester) async {
    await pumpOpener(tester, (ctx) async {
      await GoalAttachSheet.show(ctx, goals: const []);
    });
    expect(find.text('No open goals for today'), findsOneWidget);
  });
}
