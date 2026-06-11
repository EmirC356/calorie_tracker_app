import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/squad_goal.dart';
import '../../models/squad_day_entry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui/ui.dart';

/// Deprecated alias — use [AppColors.statusHit]. Kept for legacy references.
const kHit = AppColors.statusHit;

/// Status colors come from the orthogonal status palette (design/system.md):
/// identical in every room, never the section accent.
Color statusColor(GoalStatus s) {
  switch (s) {
    case GoalStatus.hit:
      return AppColors.statusHit;
    case GoalStatus.inProgress:
      return AppColors.statusInProgress;
    case GoalStatus.missed:
      return AppColors.statusMissed;
  }
}

String statusLabel(GoalStatus s) {
  switch (s) {
    case GoalStatus.hit:
      return 'HIT';
    case GoalStatus.inProgress:
      return 'IN PROGRESS';
    case GoalStatus.missed:
      return 'MISSED';
  }
}

IconData statusIcon(GoalStatus s) {
  switch (s) {
    case GoalStatus.hit:
      return LucideIcons.check;
    case GoalStatus.inProgress:
      return LucideIcons.clock;
    case GoalStatus.missed:
      return LucideIcons.x;
  }
}

/// Maps a [GoalStatus] onto the [StatusPill] variant — the one status badge
/// used everywhere in the squad room.
PillStatus pillStatusFor(GoalStatus s) {
  switch (s) {
    case GoalStatus.hit:
      return PillStatus.hit;
    case GoalStatus.inProgress:
      return PillStatus.inProgress;
    case GoalStatus.missed:
      return PillStatus.missed;
  }
}

/// A 0..1 fraction of progress toward [goal] from [entry], or null when no
/// numeric progress is available (status-only sharing, or no entry yet).
double? progressFor(SquadGoal goal, SquadDayEntry? entry) {
  if (entry == null) return null;
  if (entry.status == GoalStatus.hit) return 1.0;
  if (!entry.hasTotals) return null;
  final fracs = <double>[];
  if (goal.calorieActive && entry.consumed != null) {
    fracs.add((entry.consumed! / goal.calorieTarget!).clamp(0.0, 1.0));
  }
  if (goal.exerciseMinutesMin != null && entry.exerciseMinutes != null) {
    fracs.add((entry.exerciseMinutes! / goal.exerciseMinutesMin!).clamp(0.0, 1.0));
  }
  if (goal.caloriesBurnedMin != null && entry.burned != null) {
    fracs.add((entry.burned! / goal.caloriesBurnedMin!).clamp(0.0, 1.0));
  }
  if (fracs.isEmpty) return null;
  return fracs.reduce((a, b) => a + b) / fracs.length;
}
