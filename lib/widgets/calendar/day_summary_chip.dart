import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/index.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A tiny activity summary chip, e.g. "4 meals · 1820 kcal" or "1 ex · 30 min".
/// bodyS textSecondary on surface1, radius 8, lucide icon at left.
class DaySummaryChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const DaySummaryChip({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.s8, vertical: Spacing.s4),
      margin: const EdgeInsets.only(bottom: Spacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: Spacing.s4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.tabular(
                AppText.bodyS.copyWith(color: AppColors.textSecondary)),
          ),
        ),
      ]),
    );
  }

  /// Builds the meal + exercise (+ weight) summary chips for a [DayActivity].
  static List<Widget> forActivity(DayActivity a) {
    final chips = <Widget>[];
    if (a.mealCount > 0) {
      chips.add(DaySummaryChip(
        icon: LucideIcons.utensils,
        text:
            '${a.mealCount} meal${a.mealCount == 1 ? '' : 's'} · ${a.calories.toStringAsFixed(0)} kcal',
        color: AppColors.textTertiary,
      ));
    }
    if (a.exerciseCount > 0) {
      chips.add(DaySummaryChip(
        icon: LucideIcons.dumbbell,
        text: '${a.exerciseCount} ex · ${a.exerciseMinutes} min',
        color: AppColors.textTertiary,
      ));
    }
    if (a.hasWeight && a.weightKg != null) {
      chips.add(DaySummaryChip(
        icon: LucideIcons.scale,
        text: '${a.weightKg!.toStringAsFixed(1)} kg',
        color: AppColors.textTertiary,
      ));
    }
    return chips;
  }
}
