import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';

/// Read-only "Group goals" strip for the squad home — each active goal shows a
/// progress bar toward its target. Creating goals lives in Settings (owner-only).
class GroupGoalsStrip extends StatelessWidget {
  final String squadId;
  const GroupGoalsStrip({super.key, required this.squadId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final todayKey = ymd(DateTime.now());
    return StreamBuilder<List<SquadGroupGoal>>(
      stream: service.watchGroupGoals(squadId),
      builder: (context, snap) {
        final active = (snap.data ?? const <SquadGroupGoal>[])
            .where((g) => g.isActiveOn(todayKey))
            .toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [for (final g in active) _goalCard(g)]),
        );
      },
    );
  }

  Widget _goalCard(SquadGroupGoal g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: neonBox(g.isHit ? kNeonGreen : kNavy),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(g.isHit ? Icons.emoji_events : Icons.flag, size: 16, color: g.isHit ? kNeonGreen : kNavy),
          const SizedBox(width: 8),
          Expanded(child: Text(g.title, style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 13))),
          Text('${g.currentValue.toStringAsFixed(0)}/${g.target.toStringAsFixed(0)}',
              style: TextStyle(color: g.isHit ? kNeonGreen : kTextDim, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: g.progress,
            minHeight: 7,
            backgroundColor: kSurface,
            valueColor: AlwaysStoppedAnimation(g.isHit ? kNeonGreen : kNavy),
          ),
        ),
      ]),
    );
  }
}
