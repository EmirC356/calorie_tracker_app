import 'package:flutter/material.dart';

/// Color tokens for the athletic-editorial design system.
///
/// Source of truth: design/system.md. Surfaces are a tonal ladder (no pure
/// black, no shadows on cards); section accents are "rooms" (Squads blue,
/// Health red, Calendar amber) and are used ONLY for focus borders, primary
/// CTAs, active tab underlines, hero stats, progress fills, and the section
/// sweep. Status colors are orthogonal to sections and identical in every room.
class AppColors {
  AppColors._();

  // ── Surface ladder ──────────────────────────────────────────────────────
  static const Color surface0 = Color(0xFF0A0A0B); // app background
  static const Color surface1 = Color(0xFF141416); // cards
  static const Color surface2 = Color(0xFF1C1C1F); // raised cards
  static const Color surface3 = Color(0xFF25252A); // sheets, dialogs, popovers
  static const Color divider = Color(0xFF2A2A2F); // 1px hairlines only

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA1A1A6);
  static const Color textTertiary = Color(0xFF6E6E73);
  static const Color textDisabled = Color(0xFF48484C);

  // ── Section accents (the "rooms") ───────────────────────────────────────
  static const Color squadBlue = Color(0xFF3B82F6);
  static const Color healthRed = Color(0xFFEF4444);
  static const Color calendarAmber = Color(0xFFF59E0B);

  // ── Status palette (orthogonal to sections) ─────────────────────────────
  static const Color statusHit = Color(0xFF22C55E);
  static const Color statusInProgress = Color(0xFFF59E0B);
  static const Color statusMissed = Color(0xFFEF4444);
  static const Color statusPaused = Color(0xFF64748B);

  // ── Special ─────────────────────────────────────────────────────────────
  /// Gold ring for 30+ day streak avatars (streak-tier system).
  static const Color streakGold = Color(0xFFFFD54A);
}
