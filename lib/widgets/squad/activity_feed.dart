import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';

/// Read-only "Squad activity" feed (last 20) below the member cards — streak
/// losses, full-squad days, group-goal hits. Written by Cloud Functions.
class ActivityFeed extends StatelessWidget {
  final String squadId;
  const ActivityFeed({super.key, required this.squadId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    return StreamBuilder<List<SquadActivity>>(
      stream: service.watchActivity(squadId),
      builder: (context, snap) {
        final items = snap.data ?? const <SquadActivity>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SQUAD ACTIVITY', style: neonLabel(kNavy, size: 12)),
            const SizedBox(height: 8),
            for (final a in items) _row(a),
          ]),
        );
      },
    );
  }

  Widget _row(SquadActivity a) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(a.line, style: const TextStyle(color: kText, fontSize: 12.5))),
          if (a.createdAt != null)
            Text(DateFormat('MMM d').format(a.createdAt!), style: const TextStyle(color: kTextDim, fontSize: 10)),
        ]),
      );
}
