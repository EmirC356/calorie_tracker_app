import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';

Goal _goal(GoalCategory cat, {String? customLabel}) => Goal(
      title: 'g',
      category: cat,
      customCategoryLabel: customLabel,
      color: const Color(0xFFF5A524),
      startDate: DateTime(2026, 6, 1),
      recurrence: const RecurrenceDaily(),
      createdAt: DateTime(2026, 6, 1),
    );

GoalHistoryEntry _entry(Goal g, OccurrenceStatus s, int day) => GoalHistoryEntry(
      g,
      GoalOccurrence(goalId: 1, occurrenceDate: DateTime(2026, 6, day), status: s),
    );

void main() {
  group('categorySuccessRates', () {
    test('computes done/(done+failed) per category, excluding skipped/open', () {
      final health = _goal(GoalCategory.health);
      final study = _goal(GoalCategory.study);
      final entries = [
        _entry(health, OccurrenceStatus.done, 1),
        _entry(health, OccurrenceStatus.done, 2),
        _entry(health, OccurrenceStatus.failed, 3),
        _entry(health, OccurrenceStatus.skipped, 4), // excluded from rate
        _entry(study, OccurrenceStatus.failed, 1),
        _entry(study, OccurrenceStatus.open, 2), // excluded from rate
      ];
      final stats = categorySuccessRates(entries);

      expect(stats['Health']!.done, 2);
      expect(stats['Health']!.failed, 1);
      expect(stats['Health']!.skipped, 1);
      expect(stats['Health']!.total, 4);
      expect(stats['Health']!.successRate, closeTo(2 / 3, 0.0001));

      expect(stats['Study']!.successRate, 0); // 0 of 1 decided
      expect(stats['Study']!.open, 1);
    });

    test('a category with no decided occurrences has rate 0', () {
      final g = _goal(GoalCategory.home);
      final stats = categorySuccessRates([
        _entry(g, OccurrenceStatus.skipped, 1),
        _entry(g, OccurrenceStatus.open, 2),
      ]);
      expect(stats['Home']!.successRate, 0);
      expect(stats['Home']!.total, 2);
    });

    test('keys use the custom label for custom categories', () {
      final g = _goal(GoalCategory.custom, customLabel: 'Side project');
      final stats = categorySuccessRates([_entry(g, OccurrenceStatus.done, 1)]);
      expect(stats.keys, contains('Side project'));
    });

    test('sorted by total descending', () {
      final a = _goal(GoalCategory.health);
      final b = _goal(GoalCategory.study);
      final stats = categorySuccessRates([
        _entry(b, OccurrenceStatus.done, 1),
        _entry(a, OccurrenceStatus.done, 1),
        _entry(a, OccurrenceStatus.failed, 2),
      ]);
      expect(stats.keys.first, 'Health'); // 2 entries > Study's 1
    });
  });
}
