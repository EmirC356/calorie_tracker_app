import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';

void main() {
  Goal base({
    int? id = 7,
    GoalType type = GoalType.manual,
    TrackedMetric? metric,
    Comparator? comparator,
    double? target,
    GoalPeriod? period,
    int? minDurationMin,
    Recurrence recurrence = const RecurrenceNone(),
    TimeOfDay? timeOfDay,
    int? endDateDaysFromStart,
  }) =>
      Goal(
        id: id,
        title: 'Test goal',
        description: 'desc',
        category: GoalCategory.health,
        color: const Color(0xFFF5A524),
        priority: GoalPriority.high,
        type: type,
        metric: metric,
        comparator: comparator,
        target: target,
        period: period,
        minDurationMin: minDurationMin,
        startDate: DateTime(2026, 6, 9),
        timeOfDay: timeOfDay,
        recurrence: recurrence,
        endDateDaysFromStart: endDateDaysFromStart,
        squadVisible: true,
        reminderMinutesBefore: 30,
        morningBriefIncluded: true,
        createdAt: DateTime(2026, 6, 1, 12, 30),
        archived: false,
      );

  void expectGoalEqual(Goal a, Goal b) {
    expect(b.id, a.id);
    expect(b.title, a.title);
    expect(b.description, a.description);
    expect(b.category, a.category);
    expect(b.customCategoryLabel, a.customCategoryLabel);
    expect(b.color, a.color);
    expect(b.priority, a.priority);
    expect(b.type, a.type);
    expect(b.metric, a.metric);
    expect(b.comparator, a.comparator);
    expect(b.target, a.target);
    expect(b.period, a.period);
    expect(b.minDurationMin, a.minDurationMin);
    expect(b.startDate, a.startDate);
    expect(b.timeOfDay, a.timeOfDay);
    expect(b.recurrence.toJson(), a.recurrence.toJson());
    expect(b.endDateDaysFromStart, a.endDateDaysFromStart);
    expect(b.squadVisible, a.squadVisible);
    expect(b.reminderMinutesBefore, a.reminderMinutesBefore);
    expect(b.morningBriefIncluded, a.morningBriefIncluded);
    expect(b.createdAt, a.createdAt);
    expect(b.archived, a.archived);
  }

  group('Goal round-trip — goal types', () {
    test('manual goal survives toMap/fromMap', () {
      final g = base();
      expectGoalEqual(g, Goal.fromMap(g.toMap()));
    });

    test('manual goal survives toJson/fromJson (id stripped)', () {
      final g = base();
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      final back = Goal.fromJson(j);
      expect(back.id, isNull); // toJson drops the id
      expectGoalEqual(base(id: null), back);
    });

    for (final metric in TrackedMetric.values) {
      test('tracked goal ($metric) survives round-trip', () {
        final g = base(
          type: GoalType.tracked,
          metric: metric,
          comparator: metric == TrackedMetric.kcalTotal
              ? Comparator.lessThanOrEqual
              : Comparator.greaterThanOrEqual,
          target: 2000,
          period: GoalPeriod.week,
          minDurationMin:
              metric == TrackedMetric.exerciseSessionCount ? 25 : null,
        );
        expectGoalEqual(g, Goal.fromMap(g.toMap()));
      });
    }
  });

  group('Goal round-trip — recurrence types', () {
    final recurrences = <Recurrence>[
      const RecurrenceNone(),
      const RecurrenceDaily(),
      const RecurrenceWeekly(weekdaysMask: kMon | kWed | kFri),
      const RecurrenceWeekly(nTimesPerWeek: 3),
      RecurrenceMonthly(dayOfMonth: 15),
    ];

    for (final r in recurrences) {
      test('${r.type} ${r.paramsJson()} survives round-trip', () {
        final g = base(recurrence: r);
        final back = Goal.fromMap(g.toMap());
        expect(back.recurrence.runtimeType, r.runtimeType);
        expect(back.recurrence.toJson(), r.toJson());
      });
    }

    test('monthly day-of-month is capped at 28', () {
      expect(RecurrenceMonthly(dayOfMonth: 31).dayOfMonth, 28);
      expect(RecurrenceMonthly(dayOfMonth: 0).dayOfMonth, 1);
      expect(RecurrenceMonthly(dayOfMonth: 12).dayOfMonth, 12);
    });

    test('weekly mode flags', () {
      const dayMode = RecurrenceWeekly(weekdaysMask: kMon | kThu);
      expect(dayMode.isCountBased, isFalse);
      expect(dayMode.includesWeekday(DateTime.monday), isTrue);
      expect(dayMode.includesWeekday(DateTime.thursday), isTrue);
      expect(dayMode.includesWeekday(DateTime.tuesday), isFalse);
      const countMode = RecurrenceWeekly(nTimesPerWeek: 4);
      expect(countMode.isCountBased, isTrue);
    });
  });

  group('Goal round-trip — optional fields', () {
    test('time of day and series end survive', () {
      final g = base(
          timeOfDay: const TimeOfDay(hour: 8, minute: 5),
          endDateDaysFromStart: 30);
      final back = Goal.fromMap(g.toMap());
      expect(back.timeOfDay, const TimeOfDay(hour: 8, minute: 5));
      expect(back.endDateDaysFromStart, 30);
      expect(back.seriesEndDate, DateTime(2026, 7, 9));
    });

    test('custom category label round-trips and labels correctly', () {
      final g = base().copyWith(
          category: GoalCategory.custom, customCategoryLabel: 'Side project');
      final back = Goal.fromMap(g.toMap());
      expect(back.category, GoalCategory.custom);
      expect(back.categoryLabel, 'Side project');
    });
  });

  group('GoalOccurrence round-trip', () {
    test('survives toMap/fromMap with all fields', () {
      final occ = GoalOccurrence(
        id: 3,
        goalId: 7,
        occurrenceDate: DateTime(2026, 6, 9),
        status: OccurrenceStatus.done,
        doneAt: DateTime(2026, 6, 9, 21, 15),
        overrideFlag: true,
        periodValueCached: 1820,
        notes: 'felt great',
      );
      final back = GoalOccurrence.fromMap(occ.toMap());
      expect(back.id, 3);
      expect(back.goalId, 7);
      expect(back.occurrenceDate, DateTime(2026, 6, 9));
      expect(back.status, OccurrenceStatus.done);
      expect(back.doneAt, DateTime(2026, 6, 9, 21, 15));
      expect(back.overrideFlag, isTrue);
      expect(back.periodValueCached, 1820);
      expect(back.notes, 'felt great');
    });

    test('open occurrence has no doneAt', () {
      final occ = GoalOccurrence(goalId: 1, occurrenceDate: DateTime(2026, 6, 9));
      final back = GoalOccurrence.fromMap(occ.toMap());
      expect(back.status, OccurrenceStatus.open);
      expect(back.doneAt, isNull);
    });
  });

  group('GoalSuggestion round-trip', () {
    test('survives toMap/fromMap and expiry check', () {
      final s = GoalSuggestion(
        id: 1,
        fromUid: 'uid-a',
        fromName: 'Alex',
        squadId: 'squad-x',
        suggestedAt: DateTime(2026, 6, 1, 9),
        expiresAt: DateTime(2026, 6, 8, 9),
        status: SuggestionStatus.pending,
        payloadJson: jsonEncode({'title': 'Gym 3x'}),
      );
      final back = GoalSuggestion.fromMap(s.toMap());
      expect(back.fromUid, 'uid-a');
      expect(back.fromName, 'Alex');
      expect(back.squadId, 'squad-x');
      expect(back.suggestedAt, DateTime(2026, 6, 1, 9));
      expect(back.expiresAt, DateTime(2026, 6, 8, 9));
      expect(back.status, SuggestionStatus.pending);
      expect(back.payloadJson, s.payloadJson);
      expect(back.isExpiredAt(DateTime(2026, 6, 9)), isTrue);
      expect(back.isExpiredAt(DateTime(2026, 6, 7)), isFalse);
    });
  });
}
