import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../ui/ui.dart';

/// A compact circular progress ring with an optional center label. Used for
/// tracked-goal progress on the day view and detail dialog.
///
/// Delegates to the design-system [AnimatedRing] (surface2 track, spring
/// fill); [color] comes from the occurrence status or goal category.
class ProgressRing extends StatelessWidget {
  final double percent; // 0..100
  final Color color;
  final double size;
  final double stroke;
  final String? centerLabel;

  const ProgressRing({
    super.key,
    required this.percent,
    required this.color,
    this.size = 44,
    this.stroke = 4,
    this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0).toDouble();
    return AnimatedRing(
      progress: value,
      accent: color,
      size: size,
      strokeWidth: stroke,
      child: centerLabel == null
          ? null
          : Text(
              centerLabel!,
              style: AppText.tabular(AppText.bodyS.copyWith(
                color: color,
                fontSize: size * 0.26,
                fontWeight: FontWeight.w600,
              )),
            ),
    );
  }
}
