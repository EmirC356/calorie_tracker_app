import 'package:flutter/material.dart';
import '../../models/squad_goal.dart';
import '../../theme/app_theme.dart';

/// Renders a [SquadGoal] as a compact line, e.g. "≤ 2200 kcal & ≥ 30 min".
class GoalSummary extends StatelessWidget {
  final SquadGoal goal;
  final Color color;
  final double fontSize;
  const GoalSummary({super.key, required this.goal, this.color = kNavy, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final unset = goal.isEmpty;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(unset ? Icons.flag_outlined : Icons.flag, size: fontSize + 3, color: unset ? kTextDim : color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          goal.summary,
          style: TextStyle(color: unset ? kTextDim : kText, fontSize: fontSize, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}
