import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/squad_pause.dart';

void main() {
  group('isPausedOn', () {
    final pause = SquadPause(
      active: true,
      declaredAt: DateTime(2026, 6, 10, 9),
      until: DateTime(2026, 6, 14),
      daysUsedThisYear: 5,
    );

    test('days inside the window are paused (inclusive both ends)', () {
      expect(pause.isPausedOn(DateTime(2026, 6, 10)), isTrue);
      expect(pause.isPausedOn(DateTime(2026, 6, 12)), isTrue);
      expect(pause.isPausedOn(DateTime(2026, 6, 14)), isTrue);
    });

    test('day before declaration is not paused', () {
      expect(pause.isPausedOn(DateTime(2026, 6, 9)), isFalse);
    });

    test('day after until is not paused (auto-resume)', () {
      expect(pause.isPausedOn(DateTime(2026, 6, 15)), isFalse);
    });

    test('inactive pause is never paused', () {
      expect(pause.copyWith(active: false).isPausedOn(DateTime(2026, 6, 12)), isFalse);
    });
  });

  group('planPause', () {
    final now = DateTime(2026, 6, 10, 9);
    const fresh = SquadPause();

    test('a normal 5-day pause is ok and counts inclusively', () {
      final p = SquadPause.planPause(current: fresh, now: now, until: DateTime(2026, 6, 14));
      expect(p.ok, isTrue);
      expect(p.days, 5);
      expect(p.daysUsedThisYearAfter, 5);
    });

    test('end date in the past is rejected', () {
      final p = SquadPause.planPause(current: fresh, now: now, until: DateTime(2026, 6, 9));
      expect(p.validation, PauseValidation.endInPast);
    });

    test('window longer than 21 days is rejected', () {
      final p = SquadPause.planPause(current: fresh, now: now, until: DateTime(2026, 7, 5)); // 25 days out
      expect(p.validation, PauseValidation.windowTooLong);
    });

    test('exactly 21 days out is allowed', () {
      final p = SquadPause.planPause(current: fresh, now: now, until: DateTime(2026, 7, 1)); // 21 days
      expect(p.ok, isTrue);
    });

    test('already paused is rejected', () {
      final current = SquadPause(
        active: true, declaredAt: DateTime(2026, 6, 8), until: DateTime(2026, 6, 12));
      final p = SquadPause.planPause(current: current, now: now, until: DateTime(2026, 6, 20));
      expect(p.validation, PauseValidation.alreadyPaused);
    });

    test('exceeding the 60-day yearly cap is rejected', () {
      final current = SquadPause(daysUsedThisYear: 58);
      final p = SquadPause.planPause(current: current, now: now, until: DateTime(2026, 6, 14)); // +5 = 63
      expect(p.validation, PauseValidation.yearlyCapReached);
    });

    test('landing exactly on the 60-day cap is allowed', () {
      final current = SquadPause(daysUsedThisYear: 55);
      final p = SquadPause.planPause(current: current, now: now, until: DateTime(2026, 6, 14)); // +5 = 60
      expect(p.ok, isTrue);
      expect(p.daysUsedThisYearAfter, 60);
    });
  });

  group('serialization', () {
    test('round-trips through fromMap/toMap (ymd dates)', () {
      final p = SquadPause(
        active: true,
        until: DateTime(2026, 6, 14),
        reason: 'traveling',
        declaredAt: DateTime(2026, 6, 10, 9),
        daysUsedThisYear: 12,
      );
      final back = SquadPause.fromMap({
        'active': true,
        'until': '2026-06-14',
        'reason': 'traveling',
        'daysUsedThisYear': 12,
      });
      expect(back.active, p.active);
      expect(back.until, DateTime(2026, 6, 14));
      expect(back.reason, 'traveling');
      expect(back.daysUsedThisYear, 12);
    });
  });
}
