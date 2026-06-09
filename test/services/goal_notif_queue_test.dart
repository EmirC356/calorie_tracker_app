import 'package:flutter/material.dart' show Color, TimeOfDay;
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

  final today = DateTime(2026, 6, 9, 6, 0); // 06:00 — before an 08:00 reminder

  setUp(() {
    fs = FakeFirebaseFirestore();
    db = DatabaseService(overridePath: inMemoryDatabasePath);
    goals = GoalService(db: db);
    snapshot = SnapshotService(db: db, squadService: SquadService(firestore: fs), goalService: goals);
  });

  tearDown(() async => db.close());

  Goal goal({
    bool morningBrief = true,
    int? reminderMinutesBefore,
    TimeOfDay? time,
  }) =>
      Goal(
        title: 'Read 30 min',
        category: GoalCategory.personal,
        color: const Color(0xFFB57EDC),
        startDate: DateTime(2026, 6, 9),
        recurrence: const RecurrenceDaily(),
        morningBriefIncluded: morningBrief,
        reminderMinutesBefore: reminderMinutesBefore,
        timeOfDay: time,
        createdAt: DateTime(2026, 6, 1),
      );

  test('writes a morning brief listing today\'s briefed goals', () async {
    await goals.createGoal(goal(morningBrief: true));
    await goals.createGoal(goal(morningBrief: false));
    await snapshot.writeGoalNotifQueue(uid: 'u1', now: today);

    final brief = await fs.doc('users/u1/todaysGoalsBrief/2026-06-09').get();
    expect(brief.exists, isTrue);
    expect(brief.data()!['goalsCount'], 1);
    expect((brief.data()!['items'] as List), hasLength(1));
  });

  test('queues a reminder for a timed goal whose fire time is still ahead', () async {
    await goals.createGoal(goal(reminderMinutesBefore: 30, time: const TimeOfDay(hour: 8, minute: 0)));
    await snapshot.writeGoalNotifQueue(uid: 'u1', now: today);

    final reminders = await fs.collection('users/u1/pendingReminders').get();
    expect(reminders.docs, hasLength(1));
    final d = reminders.docs.first.data();
    expect(d['title'], 'Read 30 min');
    // fireAt = 07:30 local that day.
    expect(DateTime.parse(d['fireAt'] as String).toLocal().hour, 7);
    expect(reminders.docs.first.id, '${(await goals.listGoals()).first.id}_2026-06-09');
  });

  test('does not queue a reminder whose fire time has already passed', () async {
    final past = DateTime(2026, 6, 9, 9, 0); // 09:00, after the 07:30 fire time
    await goals.createGoal(goal(reminderMinutesBefore: 30, time: const TimeOfDay(hour: 8, minute: 0)));
    await snapshot.writeGoalNotifQueue(uid: 'u1', now: past);
    expect((await fs.collection('users/u1/pendingReminders').get()).docs, isEmpty);
  });

  test('prunes a reminder that no longer applies', () async {
    final id = await goals.createGoal(goal(reminderMinutesBefore: 30, time: const TimeOfDay(hour: 8, minute: 0)));
    await snapshot.writeGoalNotifQueue(uid: 'u1', now: today);
    expect((await fs.collection('users/u1/pendingReminders').get()).docs, hasLength(1));

    // Remove the reminder from the goal, re-run → the queued doc is pruned.
    final g = (await goals.getGoal(id))!;
    await goals.updateGoal(g.copyWith(clearReminder: true));
    await snapshot.writeGoalNotifQueue(uid: 'u1', now: today);
    expect((await fs.collection('users/u1/pendingReminders').get()).docs, isEmpty);
  });
}
