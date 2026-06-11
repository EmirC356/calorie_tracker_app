import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui/ui.dart';

/// Legacy squad progress ring — now a thin wrapper over the [AnimatedRing]
/// primitive (spring fill, surface2 track). [value] null = no numeric data:
/// rendered as a dim full ring in surface3.
class ProgressRing extends StatelessWidget {
  final double? value;
  final Color color;
  final double size;
  final Widget? center;
  const ProgressRing({super.key, required this.value, required this.color, this.size = 56, this.center});

  @override
  Widget build(BuildContext context) {
    return AnimatedRing(
      progress: value ?? 1.0,
      accent: value == null ? AppColors.surface3 : color,
      size: size,
      strokeWidth: 5,
      child: center,
    );
  }
}
