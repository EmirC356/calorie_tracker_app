import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A compact circular progress ring with an optional center label. Used for
/// tracked-goal progress on the day view and detail sheet.
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
    final value = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: stroke,
            backgroundColor: kBorderDim,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (centerLabel != null)
          Text(centerLabel!,
              style: TextStyle(
                  color: color, fontSize: size * 0.26, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
