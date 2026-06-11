import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'calendar_status.dart';

/// A chip representing a goal occurrence: 12% category-color tint, radius 8,
/// a priority dot, the bodyS title, and the status icon. Tapping opens the
/// goal detail dialog (wired by the caller).
class GoalChip extends StatelessWidget {
  final Goal goal;
  final OccurrenceStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Compact mode (calendar cells) hides the title for a dense dot+icon chip.
  final bool compact;

  const GoalChip({
    super.key,
    required this.goal,
    required this.status,
    this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = occurrenceStatusColor(status);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? Spacing.s4 : Spacing.s8,
            vertical: compact ? 2 : Spacing.s4),
        margin: const EdgeInsets.only(bottom: Spacing.s4),
        decoration: BoxDecoration(
          color: goal.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: goalPriorityColor(goal.priority), shape: BoxShape.circle),
          ),
          if (!compact) ...[
            const SizedBox(width: Spacing.s4),
            Flexible(
              child: Text(
                goal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyS.copyWith(
                    decoration: status == OccurrenceStatus.done
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: statusColor),
              ),
            ),
          ],
          SizedBox(width: compact ? 2 : Spacing.s4),
          Icon(occurrenceStatusIcon(status),
              size: compact ? 11 : 14, color: statusColor),
        ]),
      ),
    );
  }
}
