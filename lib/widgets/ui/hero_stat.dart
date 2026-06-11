import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'animated_number.dart';

/// The data-as-hero stat: a displayXL tabular number with an optional
/// "/ target" suffix and an optional uppercase caption label above
/// (e.g. "CALORIES TODAY"). The number tickers on value changes.
///
/// Pass [accent] only for celebratory states (goal hit) — default stat color
/// is textPrimary per the canon: accents never become body text.
class HeroStat extends StatelessWidget {
  final double value;
  final double? target;
  final String? label;
  final String? unit;
  final Color? accent;
  final int decimals;

  const HeroStat({
    super.key,
    required this.value,
    this.target,
    this.label,
    this.unit,
    this.accent,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppText.tabular(
      AppText.titleM.copyWith(color: AppColors.textTertiary),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!.toUpperCase(), style: AppText.caption),
          const SizedBox(height: Spacing.s4),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedNumber(
              value: value,
              decimals: decimals,
              style: AppText.displayXL.copyWith(
                color: accent ?? AppColors.textPrimary,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: Spacing.s4),
              Text(unit!, style: secondary),
            ],
            if (target != null) ...[
              const SizedBox(width: Spacing.s8),
              Text('/ ${target!.toStringAsFixed(0)}', style: secondary),
            ],
          ],
        ),
      ],
    );
  }
}
