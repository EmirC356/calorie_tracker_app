import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type-scale tokens for the athletic-editorial design system.
///
/// Display styles (hero stats, big headers) are Space Grotesk; everything else
/// is Inter. Display styles ship with tabular figures because they exist to
/// render numbers; apply [AppText.tabular] to any other style that renders a
/// number. Names and metrics come from design/system.md — use these names
/// everywhere, never ad-hoc TextStyles.
class AppText {
  AppText._();

  static const List<FontFeature> _tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  // ── Display — Space Grotesk, numbers-as-design ──────────────────────────

  /// 56sp / 700 / -0.5 — hero stats (today's calories, current weight).
  static TextStyle get displayXL => GoogleFonts.spaceGrotesk(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        fontFeatures: _tabularFigures,
      );

  /// 40sp / 700 / -0.3 — secondary heroes (analysis result, day-view date).
  static TextStyle get displayL => GoogleFonts.spaceGrotesk(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
        fontFeatures: _tabularFigures,
      );

  /// 28sp / 600 / -0.2 — section app-bar titles, row-level stat numbers.
  static TextStyle get displayM => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
        fontFeatures: _tabularFigures,
      );

  // ── Body / UI — Inter ───────────────────────────────────────────────────

  /// 22sp / 600 — card titles, squad names.
  static TextStyle get titleL => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  /// 17sp / 600 — row titles, dialog titles.
  static TextStyle get titleM => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  /// 16sp / 400 — primary body copy, setting rows.
  static TextStyle get bodyL => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  /// 14sp / 400 — secondary body copy, subtitles.
  static TextStyle get bodyM => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  /// 13sp / 500 / +0.3 — labels and chips.
  static TextStyle get bodyS => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: AppColors.textPrimary,
      );

  /// 11sp / 500 / +0.5 — UPPERCASE captions. The style does not transform the
  /// string; pass already-uppercased text (e.g. `'calories today'.toUpperCase()`).
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      );

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Returns [style] with tabular figures, for any numeric text rendered in a
  /// non-display style. ALL numbers in the app must be tabular.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: _tabularFigures);
}
