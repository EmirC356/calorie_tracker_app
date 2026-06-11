import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_motion.dart';
export 'app_spacing.dart';
export 'app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEPRECATED — legacy "furnace" palette aliases.
//
// The app moved to the athletic-editorial token system (design/system.md):
// AppColors / AppText / Spacing / AppMotion. These aliases keep existing
// feature code compiling while screens are migrated phase by phase; they map
// each furnace identifier onto its nearest semantic token. New code must use
// the token classes directly. Remove this block once no screen references it.
// ─────────────────────────────────────────────────────────────────────────────
const kBg = AppColors.surface0; // app background
const kSurface = AppColors.surface1; // app bars, inputs
const kCard = AppColors.surface2; // cards, sheets (nearest rung on the ladder)
const kBorderDim = AppColors.divider;

const kText = AppColors.textPrimary;
const kTextDim = AppColors.textSecondary;
const kWhite = AppColors.textPrimary; // no pure white in the new system

const kRed = AppColors.healthRed; // Health room accent
const kRedDeep = AppColors.healthRed;

const kNavy = AppColors.squadBlue; // Squad room accent
const kAmber = AppColors.calendarAmber; // Calendar room accent

const kCyan = AppColors.healthRed; // former primary
const kNeonRed = AppColors.statusMissed; // delete / error
const kPink = AppColors.healthRed; // fitness / exercise
const kNeonGreen = AppColors.statusHit; // success / positive
const kNeonYellow = AppColors.calendarAmber; // carbs
const kOrange = AppColors.textTertiary; // fat / oil / burned
const kPurple = AppColors.textTertiary; // alcohol / advisor

const kStreakGold = AppColors.streakGold;

// ── Goal category palette (functional, re-toned onto the new tokens) ─────────
const kCatHealth = AppColors.calendarAmber;
const kCatStudy = Color(0xFF4A90E2); // blue
const kCatHome = Color(0xFF4CC38A); // green
const kCatPersonal = Color(0xFFB57EDC); // lavender
const kCatCustom = Color(0xFF9AA0A6); // neutral gray

/// Curated 8-color goal palette offered in the color picker. Each is a light/
/// saturated hue with high relative luminance, so it clears the WCAG AA 4.5:1
/// contrast ratio against the app background (surface0 ≈ #0A0A0B).
const kGoalPalette = <Color>[
  AppColors.calendarAmber, // amber
  Color(0xFF4A90E2), // blue
  Color(0xFF4CC38A), // green
  Color(0xFFB57EDC), // lavender
  Color(0xFFFF6B66), // coral red
  Color(0xFF4ECDC4), // teal
  Color(0xFFE6C84F), // gold
  Color(0xFF9AA0A6), // gray
];

/// Default chip color for a goal category name (health/study/home/personal).
Color goalCategoryColor(String categoryName) {
  switch (categoryName) {
    case 'health':
      return kCatHealth;
    case 'study':
      return kCatStudy;
    case 'home':
      return kCatHome;
    case 'personal':
      return kCatPersonal;
    default:
      return kCatCustom;
  }
}

// ── DEPRECATED decoration helpers ─────────────────────────────────────────────
// Re-toned onto the new focus rule (1.5px accent border + 18% glow) so legacy
// screens soften immediately. New code uses AppMotion.accentGlow + explicit
// borders; these go away as Phases 3–5 migrate the screens.
BoxDecoration neonBox(Color accent, {double radius = AppRadius.r12, Color bg = AppColors.surface1}) =>
    BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
      boxShadow: AppMotion.accentGlow(accent),
    );

List<Shadow> textGlow(Color c) => [
      Shadow(color: c.withValues(alpha: 0.18), blurRadius: 12),
    ];

TextStyle neonLabel(Color c, {double size = 13, FontWeight w = FontWeight.w600}) =>
    AppText.bodyS.copyWith(color: c, fontSize: size, fontWeight: w);

// ── Theme ────────────────────────────────────────────────────────────────────

/// The app theme — dark only, built entirely from the design-system tokens.
/// Canon: design/system.md. Cards get depth from the surface ladder (no
/// borders, no shadows); accents appear only on CTAs, focus borders, and
/// active indicators.
ThemeData buildAppTheme() {
  final buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8));
  final buttonTextStyle = AppText.bodyL.copyWith(fontWeight: FontWeight.w600);

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.surface0,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.healthRed,
      onPrimary: AppColors.surface0,
      secondary: AppColors.squadBlue,
      onSecondary: AppColors.surface0,
      tertiary: AppColors.calendarAmber,
      onTertiary: AppColors.surface0,
      surface: AppColors.surface1,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surface2,
      outline: AppColors.divider,
      error: AppColors.statusMissed,
      onError: AppColors.textPrimary,
    ),
    textTheme: TextTheme(
      displayLarge: AppText.displayXL,
      displayMedium: AppText.displayL,
      displaySmall: AppText.displayM,
      headlineMedium: AppText.displayL,
      headlineSmall: AppText.displayM,
      titleLarge: AppText.titleL,
      titleMedium: AppText.titleM,
      bodyLarge: AppText.bodyL,
      bodyMedium: AppText.bodyM,
      bodySmall: AppText.bodyS.copyWith(color: AppColors.textSecondary),
      labelLarge: AppText.bodyS,
      labelMedium: AppText.bodyS.copyWith(color: AppColors.textSecondary),
      labelSmall: AppText.caption,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface0,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.titleL,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface0,
      selectedItemColor: AppColors.textPrimary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      elevation: 0,
      margin: const EdgeInsets.symmetric(
          horizontal: Spacing.s16, vertical: Spacing.s8),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface2,
      selectedColor: AppColors.surface2,
      disabledColor: AppColors.surface1,
      labelStyle: AppText.bodyS,
      secondaryLabelStyle: AppText.bodyS.copyWith(color: AppColors.textSecondary),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.s8, vertical: Spacing.s4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      side: BorderSide.none,
      showCheckmark: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.healthRed,
        foregroundColor: AppColors.surface0,
        disabledBackgroundColor: AppColors.surface2,
        disabledForegroundColor: AppColors.textDisabled,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: buttonShape,
        textStyle: buttonTextStyle,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s20, vertical: Spacing.s12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.healthRed,
        disabledForegroundColor: AppColors.textDisabled,
        side: const BorderSide(
            color: AppColors.healthRed, width: AppMotion.focusBorderWidth),
        shape: buttonShape,
        textStyle: buttonTextStyle,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s20, vertical: Spacing.s12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        textStyle: buttonTextStyle,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface1,
      labelStyle: AppText.bodyM.copyWith(color: AppColors.textSecondary),
      hintStyle: AppText.bodyM.copyWith(color: AppColors.textTertiary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r8),
        borderSide: const BorderSide(color: AppColors.surface2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r8),
        borderSide: const BorderSide(
            color: AppColors.healthRed, width: AppMotion.focusBorderWidth),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r8),
        borderSide: const BorderSide(
            color: AppColors.statusMissed, width: AppMotion.focusBorderWidth),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.healthRed
              : AppColors.surface1),
      checkColor: WidgetStateProperty.all(AppColors.surface0),
      side: const BorderSide(color: AppColors.textTertiary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface3,
      contentTextStyle: AppText.bodyM,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      titleTextStyle: AppText.titleM,
      contentTextStyle: AppText.bodyM,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface3,
      modalBackgroundColor: AppColors.surface3,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface3,
      textStyle: AppText.bodyM,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
    ),
  );
}

// ── Streak avatar tiers (feature: "make streaks loud") ───────────────────────

/// Visual treatment for a member avatar at a given streak length. The flame
/// grows and the ring escalates amber → scarlet → gold; the top tiers animate.
class StreakTier {
  final double flameSize; // 0 = no flame
  final Color? ringColor;
  final double ringWidth;
  final bool animated; // pulse the flame
  final bool strong; // stronger pulse (30+)
  const StreakTier({
    required this.flameSize,
    this.ringColor,
    this.ringWidth = 0,
    this.animated = false,
    this.strong = false,
  });
}

/// Maps a (fractional) current streak to its [StreakTier]. Thresholds:
/// 0 plain · 1–2 small · 3–6 medium · 7–13 large+amber · 14–29 large+scarlet
/// (pulse) · 30+ large+gold (strong pulse).
StreakTier streakTierFor(double streak) {
  final s = streak.floor();
  if (s < 1) return const StreakTier(flameSize: 0);
  if (s < 3) return const StreakTier(flameSize: 12);
  if (s < 7) return const StreakTier(flameSize: 16);
  if (s < 14) {
    return const StreakTier(
        flameSize: 20, ringColor: AppColors.calendarAmber, ringWidth: 2);
  }
  if (s < 30) {
    return const StreakTier(
        flameSize: 20,
        ringColor: AppColors.healthRed,
        ringWidth: 2,
        animated: true);
  }
  return const StreakTier(
      flameSize: 22,
      ringColor: AppColors.streakGold,
      ringWidth: 3,
      animated: true,
      strong: true);
}
