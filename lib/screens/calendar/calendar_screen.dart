import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Calendar / Goals tab. Placeholder until Phase 4 builds the real Day/Week/
/// Month surface; for now it states what's coming and shows the goal category
/// color legend so the amber Calendar accent and category palette are visible.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  static const _legend = <(String, Color)>[
    ('Health', kCatHealth),
    ('Study', kCatStudy),
    ('Home', kCatHome),
    ('Personal', kCatPersonal),
    ('Custom', kCatCustom),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CALENDAR'),
        titleTextStyle: const TextStyle(
          color: kAmber, fontSize: 18, fontWeight: FontWeight.bold,
          letterSpacing: 1.4, shadows: [Shadow(color: kAmber, blurRadius: 6)]),
        iconTheme: const IconThemeData(color: kAmber),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_month, size: 64, color: kAmber.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text('Calendar coming in Phase 4', style: neonLabel(kAmber, size: 16)),
            const SizedBox(height: 8),
            const Text(
              'Plan goals, track streaks, and see your day at a glance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextDim, fontSize: 13),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: neonBox(kAmber),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('CATEGORIES', style: neonLabel(kAmber, size: 12)),
                const SizedBox(height: 12),
                ..._legend.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: e.$2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(e.$1, style: const TextStyle(color: kText, fontSize: 13)),
                      ]),
                    )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
