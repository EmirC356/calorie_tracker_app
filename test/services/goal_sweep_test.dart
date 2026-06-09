import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/goal_service.dart';
import 'package:calorie_tracker_app/services/goal_sweep_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;
  late GoalService goals;
  late GoalSweepService sweep;

  setUp(() {
    db = DatabaseService(overridePath: inMemoryDatabasePath);
    goals = GoalService(db: db);
    sweep = GoalSweepService(goals);
  });

  tearDown(() async => db.close());

  Goal manualDaily({DateTime? start}) => Goal(
        title: 'Read 30 min',
        category: GoalCategory.personal,
        color: const Color(0xFFB57EDC),
        type: GoalType.manual,
        startDate: start ?? DateTime(2026, 6, 10),
        recurrence: const RecurrenceDaily(),
        createdAt: DateTime(2026, 6, 1),
      );

  Goal trackedWeekly() => Goal(
        title: 'Stay under 14000 kcal/week',
        category: GoalCategory.health,
        color: const Color(0xFFF5A524),
        type: GoalType.tracked,
        metric: TrackedMetric.kcalTotal,
        comparator: Comparator.lessThanOrEqual,
        target: 14000,
        period: GoalPeriod.week,
        startDate: DateTime(2026, 6, 1), // Monday
        recurrence: const RecurrenceWeekly(nTimesPerWeek: 1),
        createdAt: DateTime(2026, 6, 1),
      );

  group('Manual goals', () {
    test('past occurrences become failed; today stays unmaterialized', () async {
      final gid = await goals.createGoal(manualDaily(start: DateTime(2026, 6, 10)));
      final written =
          await sweep.sweepFinalizePastOccurrences(asOf: DateTime(2026, 6, 15));
      expect(written, 5); // Jun 10..14 (Jun 15 is today, not finalized)

      for (final d in [10, 11, 12, 13, 14]) {
        final occ = await goals.getOccurrence(gid, DateTime(2026, 6, d));
        expect(occ!.status, OccurrenceStatus.failed, reason: 'Jun $d');
      }
      expect(await goals.getOccurrence(gid, DateTime(2026, 6, 15)), isNull);
    });

    test('an already-done occurrence is not overwritten', () async {
      final gid = await goals.createGoal(manualDaily(start: DateTime(2026, 6, 10)));
      await goals.setOccurrenceStatus(
          goalId: gid, date: DateTime(2026, 6, 12), status: OccurrenceStatus.done);

      await sweep.sweepFinalizePastOccurrences(asOf: DateTime(2026, 6, 15));

      expect((await goals.getOccurrence(gid, DateTime(2026, 6, 12)))!.status,
          OccurrenceStatus.done);
      expect((await goals.getOccurrence(gid, DateTime(2026, 6, 11)))!.status,
          OccurrenceStatus.failed);
    });

    test('is idempotent — a second sweep writes nothing new', () async {
      await goals.createGoal(manualDaily(start: DateTime(2026, 6, 10)));
      final first =
          await sweep.sweepFinalizePastOccurrences(asOf: DateTime(2026, 6, 15));
      final second =
          await sweep.sweepFinalizePastOccurrences(asOf: DateTime(2026, 6, 15));
      expect(first, 5);
      expect(second, 0);
    });
  });

  group('Tracked goals', () {
    test('weekly goal is evaluated only for fully-past weeks, on Monday anchors',
        () async {
      final gid = await goals.createGoal(trackedWeekly());
      final evaluated = <DateTime>[];
      final ranges = <({DateTime start, DateTime end})>[];

      await sweep.sweepFinalizePastOccurrences(
        asOf: DateTime(2026, 6, 15), // Monday
        evaluateTracked: (goal, date) async {
          evaluated.add(date);
          final r = periodRange(goal.period!, date);
          ranges.add((start: r.start, end: r.endExclusive));
          return const GoalEvaluationResult(
            status: OccurrenceStatus.done,
            metricValue: 12000,
            targetValue: 14000,
          );
        },
      );

      // Weeks of Jun 1 (ends Jun 8) and Jun 8 (ends Jun 15) are fully past;
      // the week of Jun 15 is not. Anchors are Mondays.
      expect(evaluated, [DateTime(2026, 6, 1), DateTime(2026, 6, 8)]);
      expect(ranges, [
        (start: DateTime(2026, 6, 1), end: DateTime(2026, 6, 8)),
        (start: DateTime(2026, 6, 8), end: DateTime(2026, 6, 15)),
      ]);

      final occ = await goals.getOccurrence(gid, DateTime(2026, 6, 1));
      expect(occ!.status, OccurrenceStatus.done);
      expect(occ.periodValueCached, 12000);
    });

    test('with no evaluator, tracked occurrences are left unmaterialized', () async {
      final gid = await goals.createGoal(trackedWeekly());
      final written =
          await sweep.sweepFinalizePastOccurrences(asOf: DateTime(2026, 6, 15));
      expect(written, 0);
      expect(await goals.getOccurrence(gid, DateTime(2026, 6, 1)), isNull);
    });
  });
}
