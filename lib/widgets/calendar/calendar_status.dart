import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_colors.dart';
import '../ui/ui.dart' show PillStatus;

/// Status → icon/color/label, shared across goal chips, the detail sheet, and
/// the history list so the Calendar reads consistently.
// TODO(ui): clarify — widget tests (day_goal_row/goal_chip/goal_history/
// squadmate_goals) pin these Material glyphs (Icons.check_circle, …), and
// test/ is off-limits in this phase, so the lucide migration for status icons
// is deferred until the tests can be updated.
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
      return AppColors.statusHit;
    case OccurrenceStatus.failed:
      return AppColors.statusMissed;
    case OccurrenceStatus.skipped:
      return AppColors.statusPaused;
    case OccurrenceStatus.open:
      return AppColors.statusInProgress;
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

/// Maps an occurrence status onto the design-system [PillStatus] so calendar
/// status badges render through the shared StatusPill primitive.
PillStatus occurrencePillStatus(OccurrenceStatus s) {
  switch (s) {
    case OccurrenceStatus.done:
      return PillStatus.hit;
    case OccurrenceStatus.failed:
      return PillStatus.missed;
    case OccurrenceStatus.skipped:
      return PillStatus.paused;
    case OccurrenceStatus.open:
      return PillStatus.inProgress;
  }
}

Color goalPriorityColor(GoalPriority p) {
  switch (p) {
    case GoalPriority.high:
      return AppColors.statusMissed;
    case GoalPriority.medium:
      return AppColors.calendarAmber;
    case GoalPriority.low:
      return AppColors.textTertiary;
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
