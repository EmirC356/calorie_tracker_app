import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';

/// Status → icon/color/label, shared across goal chips, the detail sheet, and
/// the history list so the Calendar reads consistently.
IconData occurrenceStatusIcon(OccurrenceStatus s) {
  switch (s) {
    case OccurrenceStatus.done:
      return Icons.check_circle;
    case OccurrenceStatus.failed:
      return Icons.cancel;
    case OccurrenceStatus.skipped:
      return Icons.remove_circle;
    case OccurrenceStatus.open:
      return Icons.schedule;
  }
}

Color occurrenceStatusColor(OccurrenceStatus s) {
  switch (s) {
    case OccurrenceStatus.done:
      return const Color(0xFF4CC38A); // green
    case OccurrenceStatus.failed:
      return kNeonRed;
    case OccurrenceStatus.skipped:
      return kTextDim;
    case OccurrenceStatus.open:
      return kAmber;
  }
}

String occurrenceStatusLabel(OccurrenceStatus s) {
  switch (s) {
    case OccurrenceStatus.done:
      return 'Done';
    case OccurrenceStatus.failed:
      return 'Failed';
    case OccurrenceStatus.skipped:
      return 'Skipped';
    case OccurrenceStatus.open:
      return 'Open';
  }
}

Color goalPriorityColor(GoalPriority p) {
  switch (p) {
    case GoalPriority.high:
      return kNeonRed;
    case GoalPriority.medium:
      return kAmber;
    case GoalPriority.low:
      return kTextDim;
  }
}

/// Human-readable recurrence summary, e.g. "Every day", "Mon · Wed · Fri",
/// "3× per week", "Monthly on day 15", "One-time".
String goalScheduleLabel(Goal g) {
  final r = g.recurrence;
  switch (r) {
    case RecurrenceNone():
      return 'One-time';
    case RecurrenceDaily():
      return 'Every day';
    case RecurrenceWeekly(weekdaysMask: final m, nTimesPerWeek: final n):
      if (n != null) return '$n× per week';
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final days = [
        for (var d = 1; d <= 7; d++)
          if ((m & (1 << (d - 1))) != 0) names[d - 1]
      ];
      return days.isEmpty ? 'Weekly' : days.join(' · ');
    case RecurrenceMonthly(dayOfMonth: final d):
      return 'Monthly on day $d';
  }
}

/// Metric/target summary for a tracked goal, e.g. "≤ 2200 kcal / day".
String goalTargetLabel(Goal g) {
  if (!g.isTracked || g.metric == null || g.target == null) return '';
  final cmp = g.comparator == Comparator.lessThanOrEqual ? '≤' : '≥';
  final unit = _metricUnit(g.metric!);
  final per = g.period == GoalPeriod.week ? 'week' : 'day';
  final t = g.target!;
  final tStr = t == t.roundToDouble() ? t.toStringAsFixed(0) : t.toString();
  return '$cmp $tStr $unit / $per';
}

String _metricUnit(TrackedMetric m) {
  switch (m) {
    case TrackedMetric.kcalTotal:
      return 'kcal';
    case TrackedMetric.proteinG:
      return 'g protein';
    case TrackedMetric.exerciseMinutes:
      return 'min';
    case TrackedMetric.exerciseSessionCount:
      return 'sessions';
    case TrackedMetric.weightDeltaKg:
      return 'kg';
    case TrackedMetric.waterMl:
      return 'ml water';
  }
}
