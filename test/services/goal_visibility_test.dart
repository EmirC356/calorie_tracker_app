import 'package:flutter/material.dart' show Color;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/goal_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/services/snapshot_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FakeFirebaseFirestore fs;
  late DatabaseService db;
  late GoalService goals;
  late SnapshotService snapshot;

  final today = DateTime(2026, 6, 9);

  setUp(() async {
    fs = FakeFirebaseFirestore();
    db = DatabaseService(overridePath: inMemoryDatabasePath);
    goals = GoalService(db: db);
    final squadSvc = SquadService(firestore: fs);
    snapshot = SnapshotService(db: db, squadService: squadSvc, goalService: goals);
    // Seed a squad the user belongs to.
    await fs.doc('squads/s1').set({
      'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1', 'u2'],
      'inviteCode': '123456', 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  });

  tearDown(() async => db.close());

  Goal squadVisibleGoal({bool visible = true}) => Goal(
        title: 'Read 30 min',
        category: GoalCategory.personal,
        color: const Color(0xFFB57EDC),
        type: GoalType.manual,
        startDate: today,
        recurrence: const RecurrenceNone(),
        squadVisible: visible,
        createdAt: DateTime(2026, 6, 1),
      );

  test('pushes a goalsVisible doc with readerUids = squad members', () async {
    await goals.createGoal(squadVisibleGoal());
    await snapshot.pushGoalVisibility(uid: 'u1', now: today);

    final qs = await fs.collection('users/u1/goalsVisible').get();
    expect(qs.docs, hasLength(1));
    final d = qs.docs.first.data();
    expect(d['ownerUid'], 'u1');
    expect(d['goalTitle'], 'Read 30 min');
    expect(d['date'], '2026-06-09');
    expect((d['readerUids'] as List).toSet(), {'u1', 'u2'});
    expect((d['squadIds'] as List), ['s1']);
    expect(qs.docs.first.id, anyOf(contains('_2026-06-09')));
  });

  test('a non-squad-visible goal is not mirrored', () async {
    await goals.createGoal(squadVisibleGoal(visible: false));
    await snapshot.pushGoalVisibility(uid: 'u1', now: today);
    expect((await fs.collection('users/u1/goalsVisible').get()).docs, isEmpty);
  });

  test('flipping a goal private prunes its goalsVisible docs', () async {
    final id = await goals.createGoal(squadVisibleGoal());
    await snapshot.pushGoalVisibility(uid: 'u1', now: today);
    expect((await fs.collection('users/u1/goalsVisible').get()).docs, hasLength(1));

    final g = (await goals.getGoal(id))!;
    await goals.updateGoal(g.copyWith(squadVisible: false));
    await snapshot.pushGoalVisibility(uid: 'u1', now: today);
    expect((await fs.collection('users/u1/goalsVisible').get()).docs, isEmpty);
  });

  test('with no squads, nothing is written', () async {
    await fs.doc('squads/s1').delete();
    await goals.createGoal(squadVisibleGoal());
    await snapshot.pushGoalVisibility(uid: 'u1', now: today);
    expect((await fs.collection('users/u1/goalsVisible').get()).docs, isEmpty);
  });
}
