import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Card with a 4px section-accent left border on surface1 — the only border a
/// card is allowed by the canon (depth otherwise comes from the surface
/// ladder; no shadows). Used for goals and meal/exercise rows.
///
/// Taps fire [HapticFeedback.lightImpact] before [onTap].
class ColoredLeftBorderCard extends StatelessWidget {
  final Color accent;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ColoredLeftBorderCard({
    super.key,
    required this.accent,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.s16),
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: BorderRadius.circular(AppRadius.r12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
