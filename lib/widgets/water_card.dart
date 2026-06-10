import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../theme/app_theme.dart';

/// Today's water intake with +250 / +500 quick-add and undo-last. Lives on the
/// Meals tab.
class WaterCard extends StatelessWidget {
  const WaterCard({super.key});

  static const _blue = Color(0xFF4A90E2);

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterProvider>(
      builder: (_, wp, __) {
        final litres = (wp.todaysTotalMl / 1000).toStringAsFixed(2);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: neonBox(_blue),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.water_drop, color: _blue, size: 18),
              const SizedBox(width: 8),
              const Text('Water', style: TextStyle(color: kText, fontSize: 14)),
              const Spacer(),
              Text('${wp.todaysTotalMl} ml  ·  $litres L',
                  style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 15, shadows: textGlow(_blue))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _waterButton('+250 ml', () => wp.add(250))),
              const SizedBox(width: 8),
              Expanded(child: _waterButton('+500 ml', () => wp.add(500))),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Undo last',
                icon: const Icon(Icons.undo, color: kTextDim, size: 20),
                onPressed: wp.todaysEntries.isEmpty ? null : wp.removeLast,
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _waterButton(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            foregroundColor: _blue, side: const BorderSide(color: _blue)),
        child: Text(label),
      );
}
