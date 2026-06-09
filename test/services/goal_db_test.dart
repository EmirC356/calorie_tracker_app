import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/goal_service.dart';

void main() {
  // Run sqflite on the Dart VM (no device) against a fresh in-memory database
  // per test.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;
  late GoalService goals;

  setUp(() {
    db = DatabaseService(overridePath: inMemoryDatabasePath);
    goals = GoalService(db: db);
  });

  tearDown(() async => db.close());

  Goal makeGoal({
    String title = 'Stay under 2200 kcal',
    GoalType type = GoalType.tracked,
    bool archived = false,
  }) =>
      Goal(
        title: title,
        category: GoalCategory.health,
        color: const Color(0xFFF5A524),
        type: type,
        metric: TrackedMetric.kcalTotal,
        comparator: Comparator.lessThanOrEqual,
        target: 2200,
        period: GoalPeriod.day,
        startDate: DateTime(2026, 6, 9),
        recurrence: const RecurrenceDaily(),
        archived: archived,
        createdAt: DateTime(2026, 6, 1),
      );

  group('Goal CRUD', () {
    test('create + getGoal + listGoals', () async {
      final id = await goals.createGoal(makeGoal());
      expect(id, greaterThan(0));

      final fetched = await goals.getGoal(id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Stay under 2200 kcal');
      expect(fetched.metric, TrackedMetric.kcalTotal);

      final all = await goals.listGoals();
      expect(all, hasLength(1));
    });

    test('update persists changes', () async {
      final id = await goals.createGoal(makeGoal());
      final g = (await goals.getGoal(id))!;
      await goals.updateGoal(g.copyWith(title: 'Stay under 2000 kcal', target: 2000));
      final updated = (await goals.getGoal(id))!;
      expect(updated.title, 'Stay under 2000 kcal');
      expect(updated.target, 2000);
    });

    test('archiveGoal hides from onlyActive list but keeps the row', () async {
      final id = await goals.createGoal(makeGoal());
      await goals.archiveGoal(id);
      expect(await goals.listGoals(onlyActive: true), isEmpty);
      expect(await goals.listGoals(), hasLength(1));
      expect((await goals.getGoal(id))!.archived, isTrue);
    });
  });

  group('Occurrences', () {
    test('upsert is keyed on (goal_id, date) — second write updates', () async {
      final gid = await goals.createGoal(makeGoal());
      final firstId = await goals.upsertOccurrence(GoalOccurrence(
          goalId: gid, occurrenceDate: DateTime(2026, 6, 9)));
      final secondId = await goals.setOccurrenceStatus(
          goalId: gid,
          date: DateTime(2026, 6, 9),
          status: OccurrenceStatus.done);
      expect(secondId, firstId); // same row, not a duplicate

      final occ = await goals.getOccurrence(gid, DateTime(2026, 6, 9));
      expect(occ!.status, OccurrenceStatus.done);
      expect(occ.doneAt, isNotNull);
    });

    test('getOccurrencesInRange filters by date inclusively', () async {
      final gid = await goals.createGoal(makeGoal());
      for (final d in [DateTime(2026, 6, 8), DateTime(2026, 6, 9), DateTime(2026, 6, 12)]) {
        await goals.setOccurrenceStatus(
            goalId: gid, date: d, status: OccurrenceStatus.done);
      }
      final inRange = await goals.getOccurrencesInRange(
          DateTime(2026, 6, 9), DateTime(2026, 6, 11));
      expect(inRange, hasLength(1));
      expect(inRange.single.occurrenceDate, DateTime(2026, 6, 9));
    });

    test('marking done then skipped clears doneAt', () async {
      final gid = await goals.createGoal(makeGoal());
      await goals.setOccurrenceStatus(
          goalId: gid, date: DateTime(2026, 6, 9), status: OccurrenceStatus.done);
      await goals.setOccurrenceStatus(
          goalId: gid, date: DateTime(2026, 6, 9), status: OccurrenceStatus.skipped);
      final occ = await goals.getOccurrence(gid, DateTime(2026, 6, 9));
      expect(occ!.status, OccurrenceStatus.skipped);
      expect(occ.doneAt, isNull);
    });
  });

  group('Cascade delete', () {
    test('deleteGoal removes the goal and its occurrences', () async {
      final gid = await goals.createGoal(makeGoal());
      await goals.setOccurrenceStatus(
          goalId: gid, date: DateTime(2026, 6, 9), status: OccurrenceStatus.done);
      await goals.setOccurrenceStatus(
          goalId: gid, date: DateTime(2026, 6, 10), status: OccurrenceStatus.failed);
      expect(await goals.getOccurrencesForGoal(gid), hasLength(2));

      await goals.deleteGoal(gid);
      expect(await goals.getGoal(gid), isNull);
      expect(await goals.getOccurrencesForGoal(gid), isEmpty);
    });

    test('ON DELETE CASCADE fires on a raw goal-row delete (FK enforced)', () async {
      final gid = await goals.createGoal(makeGoal());
      await goals.setOccurrenceStatus(
          goalId: gid, date: DateTime(2026, 6, 9), status: OccurrenceStatus.done);
      final database = await db.db;
      // Delete the goal row directly (not via the service's explicit cleanup)
      // to prove the foreign-key cascade is actually enforced.
      await database.delete(DatabaseService.tablesGoals,
          where: 'id = ?', whereArgs: [gid]);
      expect(await goals.getOccurrencesForGoal(gid), isEmpty);
    });
  });

  group('Suggestions', () {
    GoalSuggestion makeSuggestion({
      String fromUid = 'uid-a',
      DateTime? expiresAt,
      SuggestionStatus status = SuggestionStatus.pending,
    }) =>
        GoalSuggestion(
          fromUid: fromUid,
          fromName: 'Alex',
          squadId: 'squad-x',
          suggestedAt: DateTime(2026, 6, 1),
          expiresAt: expiresAt ?? DateTime(2026, 6, 8),
          status: status,
          payloadJson: jsonEncode(makeGoal().toJson()),
        );

    test('insert + pending + accept/reject transitions', () async {
      final id1 = await goals.insertSuggestion(makeSuggestion());
      final id2 = await goals.insertSuggestion(makeSuggestion(fromUid: 'uid-b'));
      expect(await goals.pendingSuggestions(), hasLength(2));

      await goals.acceptSuggestion(id1);
      await goals.rejectSuggestion(id2);
      expect(await goals.pendingSuggestions(), isEmpty);
      expect((await goals.getSuggestion(id1))!.status, SuggestionStatus.accepted);
      expect((await goals.getSuggestion(id2))!.status, SuggestionStatus.rejected);
    });

    test('expireOldSuggestions only expires past-due pending rows', () async {
      final old = await goals.insertSuggestion(
          makeSuggestion(expiresAt: DateTime(2026, 6, 1)));
      final fresh = await goals.insertSuggestion(
          makeSuggestion(expiresAt: DateTime(2027, 1, 1)));
      final count = await goals.expireOldSuggestions(now: DateTime(2026, 6, 9));
      expect(count, 1);
      expect((await goals.getSuggestion(old))!.status, SuggestionStatus.expired);
      expect((await goals.getSuggestion(fresh))!.status, SuggestionStatus.pending);
    });
  });
}
