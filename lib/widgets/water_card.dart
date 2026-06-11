import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/water_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'ui/ui.dart';

/// Today's water intake with +250 / +500 quick-add and undo-last. Lives on the
/// Meals tab. Water reads in the soft blue (squadBlue doubles as the app's
/// "water" hue), hosted on a ColoredLeftBorderCard.
class WaterCard extends StatelessWidget {
  const WaterCard({super.key});

  static const _blue = AppColors.squadBlue;

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterProvider>(
      builder: (_, wp, __) {
        final litres = (wp.todaysTotalMl / 1000).toStringAsFixed(2);
        return ColoredLeftBorderCard(
          accent: _blue,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(LucideIcons.droplet, color: _blue, size: 16),
              const SizedBox(width: Spacing.s8),
              Text('WATER', style: AppText.caption),
              const Spacer(),
              Text(
                '${wp.todaysTotalMl} ml · $litres L',
                style: AppText.tabular(AppText.titleM),
              ),
            ]),
            const SizedBox(height: Spacing.s12),
            Row(children: [
              Expanded(child: _waterButton('+250 ml', () => wp.add(250))),
              const SizedBox(width: Spacing.s8),
              Expanded(child: _waterButton('+500 ml', () => wp.add(500))),
              const SizedBox(width: Spacing.s8),
              IconButton(
                tooltip: 'Undo last',
                icon: const Icon(LucideIcons.undo2,
                    color: AppColors.textSecondary, size: 18),
                onPressed: wp.todaysEntries.isEmpty ? null : wp.removeLast,
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _waterButton(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          side: const BorderSide(
              color: _blue, width: AppMotion.focusBorderWidth),
        ),
        child: Text(label, style: AppText.tabular(AppText.bodyS)),
      );
}
