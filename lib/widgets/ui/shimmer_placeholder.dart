import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Loading placeholder in the app's surface tones (surface1 → surface2
/// shimmer). Replaces every CircularProgressIndicator used during loads:
/// shape the placeholder like the content it stands in for.
///
/// Use [ShimmerPlaceholder.card] for card-shaped loads and
/// [ShimmerPlaceholder.line] for text rows, or pass a custom [child].
class ShimmerPlaceholder extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final Widget? child;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height = 96,
    this.radius = AppRadius.r12,
    this.child,
  });

  /// Card-shaped placeholder (full width, radius 12).
  const ShimmerPlaceholder.card({super.key, this.height = 96})
      : width = null,
        radius = AppRadius.r12,
        child = null;

  /// Single text-line placeholder.
  const ShimmerPlaceholder.line({super.key, this.width = 160})
      : height = 14,
        radius = AppRadius.r8,
        child = null;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface1,
      highlightColor: AppColors.surface2,
      child: child ??
          Container(
            width: width ?? double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
    );
  }
}
