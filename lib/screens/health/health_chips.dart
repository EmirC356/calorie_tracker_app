import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Small macro/stat chip used on meal/exercise timeline entries. Quiet by
/// design: surface2 pill, bodyS tabular text — the entry's big number is the
/// hero, chips are supporting data (design/system.md).
class StatBadge extends StatelessWidget {
  final String text;

  /// Retained for call-site compatibility; the athletic-editorial chip is
  /// monochrome (accents never become body text).
  final Color color;

  const StatBadge(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s8, vertical: Spacing.s4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Text(
          text,
          style: AppText.tabular(
              AppText.bodyS.copyWith(color: AppColors.textSecondary)),
        ),
      );
}

/// Labelled value column used in the meal/exercise detail bottom sheets:
/// uppercase caption label over a tabular titleM value.
class DetailChip extends StatelessWidget {
  final String label;
  final String value;

  /// Retained for call-site compatibility; values render textPrimary.
  final Color color;

  const DetailChip(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label.toUpperCase(), style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text(value, style: AppText.tabular(AppText.titleM)),
      ]);
}
