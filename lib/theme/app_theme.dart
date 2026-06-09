import 'package:flutter/material.dart';

// ── "Furnace" palette ────────────────────────────────────────────────────────
// Really-dark neutral gray base, a single confident scarlet red as the primary
// accent (matches the flame logo), and white + grays for hierarchy.
const kBg = Color(0xFF0C0C0D); // app background — near-black neutral gray
const kSurface = Color(0xFF161617); // app bars, inputs
const kCard = Color(0xFF1C1C1E); // cards, sheets
const kBorderDim = Color(0xFF2A2A2D);

const kText = Color(0xFFF4F4F5); // near-white body text
const kTextDim = Color(0xFF8A8A90); // muted labels
const kWhite = Color(0xFFFFFFFF); // sparing high-emphasis accent

// Primary accent + a deeper shade for shadows/secondary emphasis.
const kRed = Color(0xFFE5342E);
const kRedDeep = Color(0xFFB3271F);

// Squad (cloud/social) section accent — navy blue, distinct from the red
// primary, readable on the near-black base.
const kNavy = Color(0xFF4A6CF7);

// Calendar / Goals section accent — amber. Distinct from the red primary and
// the navy Squad accent, so the Goals surface reads as its own area.
const kAmber = Color(0xFFF5A524);

// Curated category palette for Goals. Each hue is chosen to sit clearly against
// the near-black furnace base (kBg); contrast is tightened in Phase 9. Used for
// goal chips and the Calendar legend.
const kCatHealth = kAmber; // amber
const kCatStudy = Color(0xFF4A90E2); // blue
const kCatHome = Color(0xFF4CC38A); // green
const kCatPersonal = Color(0xFFB57EDC); // lavender
const kCatCustom = Color(0xFF9AA0A6); // neutral gray

// ── Legacy aliases ───────────────────────────────────────────────────────────
// The screens were built against the old cyberpunk constant names. They are
// remapped here onto the red / white / gray system so the whole app restyles
// from this one file. New code should prefer kRed / kWhite / the grays.
const kCyan = kRed; // former primary (dashboard, meals, primary buttons)
const kNeonRed = Color(0xFFFF453A); // delete / error / protein — brighter red
const kPink = Color(0xFFFF6B66); // fitness / exercise — light red
const kNeonGreen = Color(0xFFEDEDEF); // success / weight / positive — white
const kNeonYellow = Color(0xFFE6E6EA); // carbs — near-white
const kOrange = Color(0xFF8E8E94); // fat / oil / burned — mid gray
const kPurple = Color(0xFF6E6E76); // alcohol / advisor — gray

// ── Decoration helpers ───────────────────────────────────────────────────────
BoxDecoration neonBox(Color accent, {double radius = 12, Color bg = kCard}) =>
    BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 9, spreadRadius: 0),
      ],
    );

List<Shadow> textGlow(Color c) => [
      Shadow(color: c.withValues(alpha: 0.45), blurRadius: 6),
      Shadow(color: c.withValues(alpha: 0.18), blurRadius: 12),
    ];

TextStyle neonLabel(Color c, {double size = 13, FontWeight w = FontWeight.w700}) =>
    TextStyle(color: c, fontSize: size, fontWeight: w, letterSpacing: 0.6, shadows: textGlow(c));

// ── Theme ────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kRed,
      onPrimary: kBg,
      secondary: kWhite,
      surface: kSurface,
      error: kNeonRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kRed,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kRed,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
        shadows: [Shadow(color: kRed, blurRadius: 6)],
      ),
      iconTheme: IconThemeData(color: kRed),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kSurface,
      selectedItemColor: kRed,
      unselectedItemColor: kTextDim,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorderDim, width: 1),
      ),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kRed,
        foregroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle:
            const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kRed,
        side: const BorderSide(color: kRed),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kRed),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      labelStyle: const TextStyle(color: kTextDim),
      hintStyle: const TextStyle(color: kTextDim),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderDim),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kRed, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: kText),
      bodyLarge: TextStyle(color: kText),
      bodySmall: TextStyle(color: kTextDim),
      titleMedium: TextStyle(color: kText, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: kText, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: kRed, fontWeight: FontWeight.bold, letterSpacing: 0.5),
    ),
    dividerTheme: const DividerThemeData(color: kBorderDim),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kRed : kSurface),
      checkColor: WidgetStateProperty.all(kWhite),
      side: const BorderSide(color: kRed),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kCard,
      contentTextStyle: const TextStyle(color: kText),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: kRed, width: 1)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kRed, width: 1)),
    ),
  );
}
