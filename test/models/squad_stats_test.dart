import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/squad_stats.dart';

void main() {
  final today = DateTime(2026, 6, 9, 14); // anchor
  DateTime day(int back) => DateTime(2026, 6, 9).subtract(Duration(days: back));

  group('computeStreak', () {
    test('counts days hit in the last 7', () {
      final hits = {day(0), day(1), day(3), day(8)}; // day(8) is outside 7
      final s = computeStreak(hits, today);
      expect(s.daysHitLast7, 3);
    });

    test('current streak counts consecutive days ending today', () {
      final hits = {day(0), day(1), day(2)};
      expect(computeStreak(hits, today).currentStreak, 3);
    });

    test('current streak survives an unlogged today (counts through yesterday)', () {
      final hits = {day(1), day(2), day(3)}; // today not hit yet
      expect(computeStreak(hits, today).currentStreak, 3);
    });

    test('current streak is 0 when neither today nor yesterday hit', () {
      final hits = {day(2), day(3)};
      expect(computeStreak(hits, today).currentStreak, 0);
    });

    test('longest streak finds the longest run in the window', () {
      // run of 4 (days 10-13) and a current run of 2 (days 0-1)
      final hits = {day(0), day(1), day(10), day(11), day(12), day(13)};
      final s = computeStreak(hits, today, window: 30);
      expect(s.longestStreak, 4);
      expect(s.currentStreak, 2);
    });

    test('empty history -> all zero', () {
      final s = computeStreak({}, today);
      expect(s.daysHitLast7, 0);
      expect(s.currentStreak, 0);
      expect(s.longestStreak, 0);
    });
  });
}
