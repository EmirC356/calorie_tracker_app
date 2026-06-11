import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../calendar/calendar_status.dart';

OccurrenceStatus _statusOf(String s) =>
    OccurrenceStatus.values.firstWhere((e) => e.name == s,
        orElse: () => OccurrenceStatus.open);

/// A squadmate's squad-visible goals for today (pure — fed a fixed list).
class SquadmateGoalsToday extends StatelessWidget {
  final List<GoalVisible> goals;
  final DateTime? asOf;
  const SquadmateGoalsToday({super.key, required this.goals, this.asOf});

  @override
  Widget build(BuildContext context) {
    final today = ymd(dateOnly(asOf ?? DateTime.now()));
    final todays = goals.where((g) => g.date == today).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("TODAY'S GOALS", style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      if (todays.isEmpty)
        Text('No goals shared for today.',
            style: AppText.bodyM.copyWith(color: AppColors.textTertiary))
      else
        ...todays.map((g) {
          final status = _statusOf(g.status);
          final color = occurrenceStatusColor(status);
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.s8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.s12, vertical: Spacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(AppRadius.r12),
              ),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: Color(g.colorArgb), shape: BoxShape.circle)),
                const SizedBox(width: Spacing.s12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.goalTitle,
                            style: AppText.bodyM
                                .copyWith(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (g.metricSummary != null)
                          Text(g.metricSummary!,
                              style: AppText.tabular(AppText.bodyS.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400))),
                      ]),
                ),
                Icon(occurrenceStatusIcon(status), color: color, size: 18),
              ]),
            ),
          );
        }),
    ]);
  }
}

/// Weekly goal stats for a squadmate (hit rate, current/longest streak) —
/// numbers-as-design, no card chrome.
class SquadmateGoalStats extends StatelessWidget {
  final List<GoalVisible> goals;
  final DateTime? asOf;
  const SquadmateGoalStats({super.key, required this.goals, this.asOf});

  @override
  Widget build(BuildContext context) {
    final s = computeGoalVisibleStats(goals, asOf: asOf);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('WEEKLY GOAL STATS', style: AppText.caption),
      const SizedBox(height: Spacing.s12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _stat('HIT RATE', '${(s.hitRate7d * 100).toStringAsFixed(0)}%',
            '${s.done7d}/${s.decided7d}'),
        _stat('STREAK', '${s.currentStreak}', 'days'),
        _stat('LONGEST', '${s.longestStreak30d}', '30d'),
      ]),
    ]);
  }

  Widget _stat(String label, String value, String sub) => Column(children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text(value, style: AppText.displayM),
        Text(sub,
            style: AppText.tabular(
                AppText.caption.copyWith(color: AppColors.textTertiary))),
      ]);
}
