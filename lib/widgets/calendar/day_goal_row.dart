import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import 'calendar_status.dart';

/// Minimum height of a Day-view goal row.
const double kDayGoalRowMinHeight = 72;

/// A large, readable goal-occurrence row for the Day (and 3-day Week) views:
/// category color dot, title at bodyLarge, a priority dot + schedule label +
/// reminder bell, and the status icon. An amber-tinted border makes goal rows
/// stand out from the meal/exercise/weight activity rows.
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: kCard,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: kDayGoalRowMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAmber.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: goal.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    goal.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: kText,
                          fontWeight: FontWeight.w600,
                          decoration:
                              status == OccurrenceStatus.done ? TextDecoration.lineThrough : null,
                          decorationColor: statusColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: goalPriorityColor(goal.priority), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        goalScheduleLabel(goal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kTextDim, fontSize: 12),
                      ),
                    ),
                    if (goal.reminderMinutesBefore != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.notifications_active, size: 14, color: kTextDim),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(width: 10),
              Icon(occurrenceStatusIcon(status), color: statusColor, size: 22),
            ]),
          ),
        ),
      ),
    );
  }
}
