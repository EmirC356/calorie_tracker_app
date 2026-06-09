import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';

/// Six ready-to-use example goals offered in the Calendar empty state. Each is a
/// template (no id) the user can tap to pre-fill the create form. [today]
/// anchors the start date.
List<Goal> goalExamples(DateTime today) {
  final start = dateOnly(today);
  Goal base({
    required String title,
    required GoalCategory category,
    required Color color,
    GoalType type = GoalType.manual,
    TrackedMetric? metric,
    Comparator? comparator,
    double? target,
    GoalPeriod? period,
    int? minDurationMin,
    required Recurrence recurrence,
  }) =>
      Goal(
        title: title,
        category: category,
        color: color,
        type: type,
        metric: metric,
        comparator: comparator,
        target: target,
        period: period,
        minDurationMin: minDurationMin,
        startDate: start,
        recurrence: recurrence,
        createdAt: today,
      );

  return [
    base(
      title: 'Stay under 2200 kcal',
      category: GoalCategory.health,
      color: kCatHealth,
      type: GoalType.tracked,
      metric: TrackedMetric.kcalTotal,
      comparator: Comparator.lessThanOrEqual,
      target: 2200,
      period: GoalPeriod.day,
      recurrence: const RecurrenceDaily(),
    ),
    base(
      title: 'Gym 3x/week',
      category: GoalCategory.health,
      color: kCatHealth,
      type: GoalType.tracked,
      metric: TrackedMetric.exerciseSessionCount,
      comparator: Comparator.greaterThanOrEqual,
      target: 3,
      period: GoalPeriod.week,
      minDurationMin: 20,
      recurrence: const RecurrenceWeekly(nTimesPerWeek: 3),
    ),
    base(
      title: '120 g protein daily',
      category: GoalCategory.health,
      color: kCatHealth,
      type: GoalType.tracked,
      metric: TrackedMetric.proteinG,
      comparator: Comparator.greaterThanOrEqual,
      target: 120,
      period: GoalPeriod.day,
      recurrence: const RecurrenceDaily(),
    ),
    base(
      title: 'Study math every Monday',
      category: GoalCategory.study,
      color: kCatStudy,
      recurrence: const RecurrenceWeekly(weekdaysMask: kMon),
    ),
    base(
      title: 'Clean the house Saturday',
      category: GoalCategory.home,
      color: kCatHome,
      recurrence: const RecurrenceWeekly(weekdaysMask: kSat),
    ),
    base(
      title: 'Read 30 min/day',
      category: GoalCategory.personal,
      color: kCatPersonal,
      recurrence: const RecurrenceDaily(),
    ),
  ];
}
