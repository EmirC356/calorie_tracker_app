import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';

void main() {
  const engine = RecurrenceEngine();

  Goal goal({
    required DateTime startDate,
    required Recurrence recurrence,
    int? endDateDaysFromStart,
    GoalType type = GoalType.manual,
    GoalPeriod? period,
  }) =>
      Goal(
        title: 'g',
        category: GoalCategory.health,
        color: const Color(0xFFF5A524),
        type: type,
        period: period,
        startDate: startDate,
        recurrence: recurrence,
        endDateDaysFromStart: endDateDaysFromStart,
        createdAt: DateTime(2026, 1, 1),
      );

  group('RecurrenceNone', () {
    test('only the start date, and only if in range', () {
      final g = goal(startDate: DateTime(2026, 6, 9), recurrence: const RecurrenceNone());
      expect(engine.occurrencesInRange(g, DateTime(2026, 6, 1), DateTime(2026, 6, 30)),
          [DateTime(2026, 6, 9)]);
      expect(engine.occurrencesInRange(g, DateTime(2026, 6, 10), DateTime(2026, 6, 30)),
          isEmpty);
    });
  });

  group('RecurrenceDaily', () {
    test('every day across 14 days', () {
      final g = goal(startDate: DateTime(2026, 6, 1), recurrence: const RecurrenceDaily());
      final occ = engine.occurrencesInRange(g, DateTime(2026, 6, 1), DateTime(2026, 6, 14));
      expect(occ, hasLength(14));
      expect(occ.first, DateTime(2026, 6, 1));
      expect(occ.last, DateTime(2026, 6, 14));
    });

    test('never returns dates before the start date', () {
      final g = goal(startDate: DateTime(2026, 6, 10), recurrence: const RecurrenceDaily());
      final occ = engine.occurrencesInRange(g, DateTime(2026, 6, 1), DateTime(2026, 6, 12));
      expect(occ, [DateTime(2026, 6, 10), DateTime(2026, 6, 11), DateTime(2026, 6, 12)]);
    });
  });

  group('RecurrenceWeekly — day-specific (Mon/Wed/Fri)', () {
    test('selects exactly the chosen weekdays', () {
      // 2026-06-01 is a Monday.
      final g = goal(
        startDate: DateTime(2026, 6, 1),
        recurrence: const RecurrenceWeekly(weekdaysMask: kMon | kWed | kFri),
      );
      final occ = engine.occurrencesInRange(g, DateTime(2026, 6, 1), DateTime(2026, 6, 14));
      // Week 1: Mon 1, Wed 3, Fri 5; Week 2: Mon 8, Wed 10, Fri 12.
      expect(occ, [
        DateTime(2026, 6, 1), DateTime(2026, 6, 3), DateTime(2026, 6, 5),
        DateTime(2026, 6, 8), DateTime(2026, 6, 10), DateTime(2026, 6, 12),
      ]);
      for (final d in occ) {
        expect([DateTime.monday, DateTime.wednesday, DateTime.friday], contains(d.weekday));
      }
    });
  });

  group('RecurrenceWeekly — count-based (N per week)', () {
    test('one Monday anchor per ISO week', () {
      final g = goal(
        startDate: DateTime(2026, 6, 1), // Monday
        recurrence: const RecurrenceWeekly(nTimesPerWeek: 3),
      );
      final occ = engine.occurrencesInRange(g, DateTime(2026, 6, 1), DateTime(2026, 6, 21));
      expect(occ, [DateTime(2026, 6, 1), DateTime(2026, 6, 8), DateTime(2026, 6, 15)]);
      for (final d in occ) {
        expect(d.weekday, DateTime.monday);
      }
    });

    test('a goal that starts mid-week first anchors the following Monday', () {
      // 2026-06-10 is a Wednesday; this week's Monday (Jun 8) precedes the start.
      final g = goal(
        startDate: DateTime(2026, 6, 10),
        recurrence: const RecurrenceWeekly(nTimesPerWeek: 2),
      );
      final occ = engine.occurrencesInRange(g, DateTime(2026, 6, 1), DateTime(2026, 6, 21));
      expect(occ, [DateTime(2026, 6, 15)]);
    });
  });

  group('RecurrenceMonthly', () {
    test('day-15 across 3 months including February', () {
      final g = goal(
        startDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceMonthly(dayOfMonth: 15),
      );
      final occ = engine.occurrencesInRange(g, DateTime(2026, 1, 1), DateTime(2026, 3, 31));
      expect(occ, [DateTime(2026, 1, 15), DateTime(2026, 2, 15), DateTime(2026, 3, 15)]);
    });

    test('capped day 31 lands on the 28th every month (no Feb 29/30/31)', () {
      final g = goal(
        startDate: DateTime(2026, 1, 28),
        recurrence: RecurrenceMonthly(dayOfMonth: 31), // capped to 28
      );
      final occ = engine.occurrencesInRange(g, DateTime(2026, 1, 1), DateTime(2026, 3, 31));
      expect(occ, [DateTime(2026, 1, 28), DateTime(2026, 2, 28), DateTime(2026, 3, 28)]);
      for (final d in occ) {
        expect(d.day, 28);
      }
    });
  });

  group('Series end enforcement', () {
    test('endDateDaysFromStart stops the series', () {
      final g = goal(
        startDate: DateTime(2026, 6, 1),
        recurrence: const RecurrenceDaily(),
        endDateDaysFromStart: 6, // ends 2026-06-07 inclusive
      );
      final occ = engine.occurrencesInRange(g, DateTime(2026, 6, 1), DateTime(2026, 6, 30));
      expect(occ, hasLength(7));
      expect(occ.last, DateTime(2026, 6, 7));
    });

    test('endDateDaysFromStart = 0 means a single day', () {
      final g = goal(
        startDate: DateTime(2026, 6, 1),
        recurrence: const RecurrenceDaily(),
        endDateDaysFromStart: 0,
      );
      expect(engine.occurrencesInRange(g, DateTime(2026, 6, 1), DateTime(2026, 6, 30)),
          [DateTime(2026, 6, 1)]);
    });
  });

  group('periodRange', () {
    test('day period is that single day', () {
      final r = periodRange(GoalPeriod.day, DateTime(2026, 6, 10, 14));
      expect(r.start, DateTime(2026, 6, 10));
      expect(r.endExclusive, DateTime(2026, 6, 11));
    });

    test('week period is the Mon–Sun ISO week', () {
      // 2026-06-10 is a Wednesday.
      final r = periodRange(GoalPeriod.week, DateTime(2026, 6, 10));
      expect(r.start, DateTime(2026, 6, 8)); // Monday
      expect(r.endExclusive, DateTime(2026, 6, 15)); // next Monday
    });
  });
}
