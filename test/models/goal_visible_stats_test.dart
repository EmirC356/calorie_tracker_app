import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';

GoalVisible gv(String date, String status) => GoalVisible(
      id: '$status-$date',
      ownerUid: 'u',
      goalTitle: 'g',
      category: 'Health',
      colorArgb: 0,
      priority: 'medium',
      date: date,
      status: status,
    );

void main() {
  final today = DateTime(2026, 6, 10); // anchor

  test('hit rate over last 7 days counts done vs (done+failed)', () {
    final stats = computeGoalVisibleStats([
      gv('2026-06-10', 'done'),
      gv('2026-06-09', 'done'),
      gv('2026-06-08', 'failed'),
      gv('2026-06-07', 'skipped'), // excluded
      gv('2026-06-06', 'open'), // excluded
    ], asOf: today);
    expect(stats.done7d, 2);
    expect(stats.decided7d, 3);
    expect(stats.hitRate7d, closeTo(2 / 3, 0.0001));
  });

  test('current streak counts consecutive successful days, stops at a failure', () {
    final stats = computeGoalVisibleStats([
      gv('2026-06-10', 'done'),
      gv('2026-06-09', 'done'),
      gv('2026-06-08', 'failed'),
      gv('2026-06-07', 'done'),
    ], asOf: today);
    expect(stats.currentStreak, 2); // 06-10, 06-09
  });

  test('a day with any failure is not successful', () {
    final stats = computeGoalVisibleStats([
      gv('2026-06-10', 'done'),
      gv('2026-06-10', 'failed'), // same day → not a success
    ], asOf: today);
    expect(stats.currentStreak, 0);
  });

  test('current streak survives an undecided today', () {
    final stats = computeGoalVisibleStats([
      // nothing for 06-10 (today) → undecided; streak anchored to yesterday
      gv('2026-06-09', 'done'),
      gv('2026-06-08', 'done'),
    ], asOf: today);
    expect(stats.currentStreak, 2);
  });

  test('longest streak over 30 days', () {
    final stats = computeGoalVisibleStats([
      gv('2026-06-10', 'done'),
      gv('2026-06-09', 'done'),
      gv('2026-06-08', 'done'),
      gv('2026-06-06', 'done'), // gap on 06-07
    ], asOf: today);
    expect(stats.longestStreak30d, 3);
  });

  test('empty docs yield zeros', () {
    final stats = computeGoalVisibleStats(const [], asOf: today);
    expect(stats.hitRate7d, 0);
    expect(stats.currentStreak, 0);
    expect(stats.longestStreak30d, 0);
  });
}
