import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Read-only "Squad activity" feed (last 20) below the member carousel —
/// streak losses, full-squad days, group-goal hits. Written by Cloud
/// Functions. Styled as a timeline: a 2px surface2 spine on the left, caption
/// timestamps, bodyM text, no card backgrounds.
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
          padding: const EdgeInsets.fromLTRB(
              Spacing.s16, Spacing.s8, Spacing.s16, Spacing.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SQUAD ACTIVITY', style: AppText.caption),
            const SizedBox(height: Spacing.s8),
            // Timeline spine: 2px surface2 vertical line, square corners.
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.surface2, width: 2),
                ),
              ),
              padding: const EdgeInsets.only(left: Spacing.s12),
              child: Column(children: [for (final a in items) _row(a)]),
            ),
          ]),
        );
      },
    );
  }

  Widget _row(SquadActivity a) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: Spacing.s8),
          Expanded(child: Text(a.line, style: AppText.bodyM)),
          if (a.createdAt != null) ...[
            const SizedBox(width: Spacing.s8),
            Text(
              DateFormat('MMM d').format(a.createdAt!).toUpperCase(),
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ]),
      );
}
