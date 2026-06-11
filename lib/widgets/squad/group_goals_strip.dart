import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';

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
          padding: const EdgeInsets.fromLTRB(
              Spacing.s16, Spacing.s12, Spacing.s16, 0),
          child: Column(children: [
            for (final g in active)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.s8),
                child: _goalCard(g),
              ),
          ]),
        );
      },
    );
  }

  Widget _goalCard(SquadGroupGoal g) {
    final accent = g.isHit ? AppColors.statusHit : AppColors.squadBlue;
    return ColoredLeftBorderCard(
      accent: accent,
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.s16, vertical: Spacing.s12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(g.isHit ? LucideIcons.trophy : LucideIcons.flag,
              size: 16, color: accent),
          const SizedBox(width: Spacing.s8),
          Expanded(child: Text(g.title, style: AppText.bodyS)),
          Text(
            '${g.currentValue.toStringAsFixed(0)}/${g.target.toStringAsFixed(0)}',
            style: AppText.tabular(AppText.bodyS.copyWith(
                color: g.isHit ? AppColors.statusHit : AppColors.textSecondary)),
          ),
        ]),
        const SizedBox(height: Spacing.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: g.progress,
            minHeight: 6,
            backgroundColor: AppColors.surface2,
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      ]),
    );
  }
}
