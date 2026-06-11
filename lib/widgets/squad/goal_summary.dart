import 'package:flutter/material.dart';
import '../../models/squad_goal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Renders a [SquadGoal] as a compact line, e.g. "≤ 2200 kcal & ≥ 30 min".
///
/// Note: the flag glyph stays Material (Icons.flag / Icons.flag_outlined) —
/// the unit tests pin it. Numbers in the summary render tabular.
class GoalSummary extends StatelessWidget {
  final SquadGoal goal;
  final Color color;
  final double fontSize;
  const GoalSummary({
    super.key,
    required this.goal,
    this.color = AppColors.squadBlue,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final unset = goal.isEmpty;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        unset ? Icons.flag_outlined : Icons.flag,
        size: fontSize + 3,
        color: unset ? AppColors.textTertiary : color,
      ),
      const SizedBox(width: Spacing.s8),
      Flexible(
        child: Text(
          goal.summary,
          style: AppText.tabular(AppText.bodyM.copyWith(
            color: unset ? AppColors.textTertiary : AppColors.textSecondary,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          )),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}
