import 'package:flutter/material.dart';
import '../../models/photo.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'goal_row.dart';

/// Bottom sheet listing the uploader's open goals for today. Picking one returns
/// its [PhotoGoalRef] (attaching a manual goal also marks it done — Task 6).
class GoalAttachSheet extends StatelessWidget {
  final List<PhotoGoalRef> goals;
  const GoalAttachSheet({super.key, required this.goals});

  static Future<PhotoGoalRef?> show(BuildContext context, {required List<PhotoGoalRef> goals}) =>
      showModalBottomSheet<PhotoGoalRef>(
        context: context,
        backgroundColor: AppColors.surface3,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
        builder: (_) => GoalAttachSheet(goals: goals),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: Spacing.s8),
        Center(
          child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(2))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s12, Spacing.s16, Spacing.s8),
          child: Text('ATTACH A GOAL', style: AppText.caption),
        ),
        if (goals.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s8, Spacing.s16, Spacing.s8),
            child: Text('No open goals for today',
                style: AppText.bodyM.copyWith(color: AppColors.textTertiary)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: Spacing.s8, bottom: Spacing.s8),
              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
            child: Column(
              children: [
                for (final g in goals)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context, g),
                    child: GoalRow(
                      title: g.title,
                      subtitle: g.category.isNotEmpty ? g.category : null,
                      dotColor: Color(g.colorArgb),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Spacing.s8),
      ]),
    );
  }
}
