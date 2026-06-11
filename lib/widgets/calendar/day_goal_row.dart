import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../ui/ui.dart';
import 'calendar_status.dart';

/// Minimum height of a Day-view goal row.
const double kDayGoalRowMinHeight = 72;

/// A large, readable goal-occurrence row for the Day view: a
/// [ColoredLeftBorderCard] with the goal's category color as the 4px left
/// border, the title at bodyL, a priority dot + schedule label + reminder
/// bell, and the status icon at right.
// TODO(ui): clarify — spec suggests StatusPill for status badges, but the
// day_goal_row widget test pins the Material status glyphs
// (Icons.schedule/check_circle) and test/ is off-limits; keeping the
// icon-based status retoned to the status palette.
class DayGoalRow extends StatelessWidget {
  final Goal goal;
  final OccurrenceStatus status;
  final VoidCallback? onTap;

  const DayGoalRow({
    super.key,
    required this.goal,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = occurrenceStatusColor(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kDayGoalRowMinHeight),
        child: ColoredLeftBorderCard(
          accent: goal.color,
          onTap: onTap,
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyL.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: status == OccurrenceStatus.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: statusColor,
                      ),
                    ),
                    const SizedBox(height: Spacing.s4),
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: goalPriorityColor(goal.priority),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: Spacing.s8),
                      Flexible(
                        child: Text(
                          goalScheduleLabel(goal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyS
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      if (goal.reminderMinutesBefore != null) ...[
                        const SizedBox(width: Spacing.s8),
                        const Icon(Icons.notifications_active,
                            size: 14, color: AppColors.textTertiary),
                      ],
                    ]),
                  ]),
            ),
            const SizedBox(width: Spacing.s12),
            Icon(occurrenceStatusIcon(status), color: statusColor, size: 22),
          ]),
        ),
      ),
    );
  }
}
