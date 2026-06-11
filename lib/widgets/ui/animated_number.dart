import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

/// Text widget that smoothly "tickers" between numeric values.
///
/// Used wherever a stat updates: the value tweens over 600ms (easeOutCubic)
/// from the previously shown number, starting at 0 on first build so screens
/// open with the ticker effect. Tabular figures are enforced on whatever
/// [style] is passed — numbers never shift layout while ticking.
class AnimatedNumber extends StatelessWidget {
  final double value;
  final TextStyle style;
  final int decimals;
  final String prefix;
  final String suffix;

  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppMotion.numberTicker,
      curve: AppMotion.numberTickerCurve,
      builder: (context, v, _) => Text(
        '$prefix${v.toStringAsFixed(decimals)}$suffix',
        style: AppText.tabular(style),
      ),
    );
  }
}
