import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Status variants for [StatusPill] — orthogonal to section accents and
/// identical in every room.
enum PillStatus { hit, inProgress, missed, paused }

/// Small pill (radius 999, 8h × 4v padding) with a lucide icon + label in the
/// status color over a 12% alpha tint — never a solid status fill, per the
/// no-solid-fills focus rule. Use for goal/day status everywhere.
class StatusPill extends StatelessWidget {
  final PillStatus status;
  final String? label;

  const StatusPill({super.key, required this.status, this.label});

  static const _config = {
    PillStatus.hit: (LucideIcons.check, 'Hit', AppColors.statusHit),
    PillStatus.inProgress:
        (LucideIcons.clock, 'In progress', AppColors.statusInProgress),
    PillStatus.missed: (LucideIcons.x, 'Missed', AppColors.statusMissed),
    PillStatus.paused: (LucideIcons.pause, 'Paused', AppColors.statusPaused),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, defaultLabel, color) = _config[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.s8, vertical: Spacing.s4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Spacing.s4),
          Text(label ?? defaultLabel, style: AppText.bodyS.copyWith(color: color)),
        ],
      ),
    );
  }
}
