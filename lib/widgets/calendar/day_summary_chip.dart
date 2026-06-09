import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';

/// A tiny activity summary pill, e.g. "4 meals · 1820 kcal" or "1 ex · 30 min".
class DaySummaryChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const DaySummaryChip({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kTextDim, fontSize: 10)),
        ),
      ]),
    );
  }

  /// Builds the meal + exercise (+ weight) summary chips for a [DayActivity].
  static List<Widget> forActivity(DayActivity a) {
    final chips = <Widget>[];
    if (a.mealCount > 0) {
      chips.add(DaySummaryChip(
        icon: Icons.restaurant,
        text: '${a.mealCount} meal${a.mealCount == 1 ? '' : 's'} · ${a.calories.toStringAsFixed(0)} kcal',
        color: kCyan,
      ));
    }
    if (a.exerciseCount > 0) {
      chips.add(DaySummaryChip(
        icon: Icons.fitness_center,
        text: '${a.exerciseCount} ex · ${a.exerciseMinutes} min',
        color: kPink,
      ));
    }
    if (a.hasWeight && a.weightKg != null) {
      chips.add(DaySummaryChip(
        icon: Icons.monitor_weight,
        text: '${a.weightKg!.toStringAsFixed(1)} kg',
        color: kNeonGreen,
      ));
    }
    return chips;
  }
}
