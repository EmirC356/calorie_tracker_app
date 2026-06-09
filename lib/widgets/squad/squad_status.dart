import 'package:flutter/material.dart';
import '../../models/squad_goal.dart';
import '../../models/squad_day_entry.dart';
import '../../theme/app_theme.dart';

/// Semantic status color (a literal green for "hit" reads clearly even in the
/// red/navy/white theme).
const kHit = Color(0xFF34C759);

Color statusColor(GoalStatus s) {
  switch (s) {
    case GoalStatus.hit:
      return kHit;
    case GoalStatus.inProgress:
      return kNavy;
    case GoalStatus.missed:
      return kNeonRed;
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
      return Icons.check;
    case GoalStatus.inProgress:
      return Icons.hourglass_bottom;
    case GoalStatus.missed:
      return Icons.close;
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
