import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import '../calendar/calendar_status.dart';

OccurrenceStatus _statusOf(String s) =>
    OccurrenceStatus.values.firstWhere((e) => e.name == s,
        orElse: () => OccurrenceStatus.open);

/// A squadmate's squad-visible goals for today (pure — fed a fixed list).
class SquadmateGoalsToday extends StatelessWidget {
  final List<GoalVisible> goals;
  final DateTime? asOf;
  const SquadmateGoalsToday({super.key, required this.goals, this.asOf});

  @override
  Widget build(BuildContext context) {
    final today = ymd(dateOnly(asOf ?? DateTime.now()));
    final todays = goals.where((g) => g.date == today).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("TODAY'S GOALS", style: neonLabel(kNavy, size: 12)),
      const SizedBox(height: 8),
      if (todays.isEmpty)
        const Text('No goals shared for today.', style: TextStyle(color: kTextDim, fontSize: 13))
      else
        ...todays.map((g) {
          final status = _statusOf(g.status);
          final color = occurrenceStatusColor(status);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorderDim),
              ),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(g.colorArgb), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.goalTitle, style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (g.metricSummary != null)
                      Text(g.metricSummary!, style: const TextStyle(color: kTextDim, fontSize: 11)),
                  ]),
                ),
                Icon(occurrenceStatusIcon(status), color: color, size: 18),
              ]),
            ),
          );
        }),
    ]);
  }
}

/// Weekly goal stats card for a squadmate (hit rate, current/longest streak),
/// in the same navy style as the calorie/exercise stats cards.
class SquadmateGoalStats extends StatelessWidget {
  final List<GoalVisible> goals;
  final DateTime? asOf;
  const SquadmateGoalStats({super.key, required this.goals, this.asOf});

  @override
  Widget build(BuildContext context) {
    final s = computeGoalVisibleStats(goals, asOf: asOf);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kNavy),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WEEKLY GOAL STATS', style: neonLabel(kNavy, size: 12)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('HIT RATE', '${(s.hitRate7d * 100).toStringAsFixed(0)}%', '${s.done7d}/${s.decided7d}'),
          _stat('STREAK', '${s.currentStreak}', 'days'),
          _stat('LONGEST', '${s.longestStreak30d}', '30d'),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value, String sub) => Column(children: [
        Text(label, style: const TextStyle(color: kTextDim, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(color: kTextDim, fontSize: 10)),
      ]);
}
