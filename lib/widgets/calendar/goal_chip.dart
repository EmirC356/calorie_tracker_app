import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import 'calendar_status.dart';

/// A pill representing a goal occurrence: category color, a priority dot, the
/// title, and the status icon (✓ done, ✗ failed, ⏳ open, ⊝ skipped).
/// Tapping opens the goal detail sheet (wired by the caller).
class GoalChip extends StatelessWidget {
  final Goal goal;
  final OccurrenceStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Compact mode (calendar cells) hides the title for a dense dot+icon pill.
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 8, vertical: compact ? 2 : 5),
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          color: goal.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: goal.color.withValues(alpha: 0.55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: goalPriorityColor(goal.priority), shape: BoxShape.circle),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                goal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: kText,
                    fontSize: 12,
                    decoration: status == OccurrenceStatus.done
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: statusColor),
              ),
            ),
          ],
          SizedBox(width: compact ? 3 : 6),
          Icon(occurrenceStatusIcon(status), size: compact ? 11 : 14, color: statusColor),
        ]),
      ),
    );
  }
}
