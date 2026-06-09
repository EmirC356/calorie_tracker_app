import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A circular progress ring. [value] null = no numeric data (a dim full ring).
class ProgressRing extends StatelessWidget {
  final double? value;
  final Color color;
  final double size;
  final Widget? center;
  const ProgressRing({super.key, required this.value, required this.color, this.size = 56, this.center});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: value ?? 1.0,
            strokeWidth: 5,
            backgroundColor: kBorderDim,
            valueColor: AlwaysStoppedAnimation<Color>(value == null ? kBorderDim : color),
          ),
        ),
        if (center != null) center!,
      ]),
    );
  }
}
