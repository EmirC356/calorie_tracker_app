import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Small colored pill used on meal/exercise cards. Extracted from the old
/// home_screen so the Meals and Fitness sub-tabs can share it.
class StatBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatBadge(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

/// Labelled value column used in the meal/exercise detail bottom sheets.
class DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const DetailChip(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: const TextStyle(color: kTextDim, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                shadows: textGlow(color))),
      ]);
}
