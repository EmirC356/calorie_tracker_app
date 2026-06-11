import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../ui/status_pill.dart';

/// One goal in a member's "Today's goals" list — the primary effective goal
/// (calorie/exercise), a squad-visible Calendar goal occurrence, or a non-graded
/// event (🎂 birthday, Task 6). Pure presentation.
class GoalRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? dotColor; // category color for Calendar goals
  final String? leadingEmoji; // e.g. 🎂 for events (no dot/pill)
  final PillStatus? status; // null → no status pill (events)

  const GoalRow({
    super.key,
    required this.title,
    this.subtitle,
    this.dotColor,
    this.leadingEmoji,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
        child: Row(children: [
          if (leadingEmoji != null)
            Text(leadingEmoji!, style: const TextStyle(fontSize: 16))
          else if (dotColor != null)
            Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          if (leadingEmoji != null || dotColor != null) const SizedBox(width: Spacing.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppText.bodyM.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(subtitle!,
                    style: AppText.tabular(
                        AppText.bodyS.copyWith(color: AppColors.textSecondary))),
            ]),
          ),
          if (status != null) ...[
            const SizedBox(width: Spacing.s8),
            StatusPill(status: status!),
          ],
        ]),
      ),
    );
  }
}
