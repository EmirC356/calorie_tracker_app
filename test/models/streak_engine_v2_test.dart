import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/streak_engine_v2.dart';

void main() {
  // Build a chronological history starting [n] days before [end] (inclusive),
  // one StreakDay per status in order.
  List<StreakDay> hist(List<StreakStatus> statuses,
      {List<int> redeemedIndexes = const [], DateTime? end}) {
    final last = end ?? DateTime(2026, 6, 30);
    final start = last.subtract(Duration(days: statuses.length - 1));
    return [
      for (var i = 0; i < statuses.length; i++)
        StreakDay(
          date: start.add(Duration(days: i)),
          status: statuses[i],
          redeemed: redeemedIndexes.contains(i),
        ),
    ];
  }

  const H = StreakStatus.hit;
  const M = StreakStatus.missed;
  const P = StreakStatus.paused;
  const I = StreakStatus.inProgress;

  group('basics', () {
    test('empty history → all zero/false', () {
      final r = computeStreakV2([]);
      expect(r.currentStreak, 0);
      expect(r.longestStreak, 0);
      expect(r.atRiskFlag, isFalse);
      expect(r.brokenToday, isFalse);
    });

    test('single hit → 1', () {
      expect(computeStreakV2(hist([H])).currentStreak, 1);
    });

    test('consecutive hits → count', () {
      final r = computeStreakV2(hist([H, H, H, H, H]));
      expect(r.currentStreak, 5);
      expect(r.longestStreak, 5);
    });

    test('longest == current for pure hits', () {
      final r = computeStreakV2(hist([H, H, H]));
      expect(r.currentStreak, r.longestStreak);
    });
  });

  group('misses & make-ups', () {
    test('a missed day resets', () {
      final r = computeStreakV2(hist([H, H, H, M]));
      expect(r.currentStreak, 0);
      expect(r.longestStreak, 3);
    });

    test('missed recovered by make-up continues at +0.5', () {
      final r = computeStreakV2(hist([H, H, H, M], redeemedIndexes: [3]));
      expect(r.currentStreak, 3.5);
      expect(r.longestStreak, 3.5);
    });

    test('make-up half then a hit → 14.5 style', () {
      final statuses = [for (var i = 0; i < 13; i++) H, M, H];
      final r = computeStreakV2(hist(statuses, redeemedIndexes: [13]));
      expect(r.currentStreak, 14.5);
      expect(r.longestStreak, 14.5);
    });

    test('make-up day that also hits → 1.5 credit across two days', () {
      // day N missed(redeemed)=0.5, day N+1 hit=1.0 over a base of 2.
      final r = computeStreakV2(hist([H, H, M, H], redeemedIndexes: [2]));
      expect(r.currentStreak, 3.5);
    });

    test('redeemed miss then a real miss breaks', () {
      final r = computeStreakV2(hist([H, H, H, M, M], redeemedIndexes: [3]));
      expect(r.currentStreak, 0);
      expect(r.longestStreak, 3.5);
    });

    test('two separate streaks: longest is the bigger run', () {
      final r = computeStreakV2(hist([H, H, H, H, H, H, H, M, H, H, H]));
      expect(r.currentStreak, 3);
      expect(r.longestStreak, 7);
    });
  });

  group('pause (freeze)', () {
    test('a paused day freezes the streak', () {
      expect(computeStreakV2(hist([H, H, H, P])).currentStreak, 3);
    });

    test('multiple consecutive pauses freeze, then resume', () {
      expect(computeStreakV2(hist([H, H, P, P, P, P, H])).currentStreak, 3);
    });

    test('hit after a long pause with no prior streak starts at 1', () {
      expect(computeStreakV2(hist([P, P, P, H])).currentStreak, 1);
    });

    test('pause in the middle then resume extends', () {
      expect(computeStreakV2(hist([H, H, H, P, P, H, H])).currentStreak, 5);
    });

    test('all paused → 0', () {
      final r = computeStreakV2(hist([P, P, P]));
      expect(r.currentStreak, 0);
      expect(r.longestStreak, 0);
    });

    test('pause exactly at threshold keeps the streak, no break', () {
      final r = computeStreakV2(hist([H, H, H, H, H, P]));
      expect(r.currentStreak, 5);
      expect(r.brokenToday, isFalse);
    });

    test('paused-then-missed breaks', () {
      final r = computeStreakV2(hist([H, H, H, H, H, P, M]));
      expect(r.currentStreak, 0);
      expect(r.brokenToday, isTrue);
    });
  });

  group('inProgress (today pending)', () {
    test('inProgress today does not extend yet', () {
      expect(computeStreakV2(hist([H, H, H, H, I])).currentStreak, 4);
    });

    test('inProgress does not break the streak', () {
      final r = computeStreakV2(hist([H, H, H, I]));
      expect(r.currentStreak, 3);
      expect(r.brokenToday, isFalse);
    });
  });

  group('atRiskFlag', () {
    test('inProgress today past 18:00 → at risk', () {
      final today = DateTime(2026, 6, 30, 19);
      final r = computeStreakV2(hist([H, H, H, I], end: DateTime(2026, 6, 30)), now: today);
      expect(r.atRiskFlag, isTrue);
    });

    test('inProgress today before 18:00 → not at risk', () {
      final today = DateTime(2026, 6, 30, 17);
      final r = computeStreakV2(hist([H, H, H, I], end: DateTime(2026, 6, 30)), now: today);
      expect(r.atRiskFlag, isFalse);
    });

    test('today already hit → not at risk', () {
      final today = DateTime(2026, 6, 30, 21);
      final r = computeStreakV2(hist([H, H, H, H], end: DateTime(2026, 6, 30)), now: today);
      expect(r.atRiskFlag, isFalse);
    });

    test('no now provided → not at risk', () {
      expect(computeStreakV2(hist([H, I])).atRiskFlag, isFalse);
    });

    test('stale inProgress (dated yesterday) → not at risk', () {
      final now = DateTime(2026, 7, 1, 20);
      final r = computeStreakV2(hist([H, H, I], end: DateTime(2026, 6, 30)), now: now);
      expect(r.atRiskFlag, isFalse);
    });
  });

  group('brokenToday', () {
    test('streak ≥ threshold broken → true', () {
      expect(computeStreakV2(hist([H, H, H, H, H, M])).brokenToday, isTrue);
    });

    test('streak below threshold broken → false', () {
      expect(computeStreakV2(hist([H, H, H, M])).brokenToday, isFalse);
    });

    test('redeemed miss does not count as broken', () {
      final r = computeStreakV2(hist([H, H, H, H, H, M], redeemedIndexes: [5]));
      expect(r.brokenToday, isFalse);
      expect(r.currentStreak, 5.5);
    });

    test('break attributed only to the last finalized day (paused after)', () {
      // The break happened on the missed day; a paused day after it means the
      // most-recently-finalized day is the pause, so brokenToday is false.
      expect(computeStreakV2(hist([H, H, H, H, H, M, P])).brokenToday, isFalse);
    });

    test('redeemed run reaching ≥ threshold then a real miss → broken', () {
      final r = computeStreakV2(hist([H, H, H, H, H, M, M], redeemedIndexes: [5]));
      expect(r.currentStreak, 0);
      expect(r.brokenToday, isTrue); // pre-break value was 5.5
    });

    test('custom threshold respected', () {
      final r = computeStreakV2(hist([H, H, H, M]), breakThreshold: 3);
      expect(r.brokenToday, isTrue);
    });

    test('inProgress after a break: brokenToday still reflects the missed day', () {
      final r = computeStreakV2(hist([H, H, H, H, H, M, I]));
      expect(r.brokenToday, isTrue);
      expect(r.currentStreak, 0);
    });

    test('empty history → not broken', () {
      expect(computeStreakV2([]).brokenToday, isFalse);
    });
  });
}
