import 'package:flutter/material.dart';

// ── Cyberpunk palette ──────────────────��─────────────────────────────────────
const kBg = Color(0xFF0A0A14);
const kSurface = Color(0xFF141428);
const kCard = Color(0xFF1E1E38);
const kCyan = Color(0xFF00E5FF);
const kPink = Color(0xFFFF1B8D);
const kNeonGreen = Color(0xFF00FF88);
const kNeonYellow = Color(0xFFFFE000);
const kPurple = Color(0xFFBF40FF);
const kOrange = Color(0xFFFF6500);
const kNeonRed = Color(0xFFFF2355);
const kText = Color(0xFFE0E8FF);
const kTextDim = Color(0xFF5A6080);
const kBorderDim = Color(0xFF2A2A4A);

// ── Decoration helpers ─────────────────────────────────���─────────────────────
BoxDecoration neonBox(Color accent, {double radius = 12, Color bg = kCard}) =>
    BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.7), width: 1),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 10, spreadRadius: 0),
      ],
    );

List<Shadow> textGlow(Color c) => [
      Shadow(color: c.withValues(alpha: 0.9), blurRadius: 8),
      Shadow(color: c.withValues(alpha: 0.4), blurRadius: 16),
    ];

TextStyle neonLabel(Color c, {double size = 13, FontWeight w = FontWeight.w600}) =>
    TextStyle(color: c, fontSize: size, fontWeight: w, shadows: textGlow(c));

// ── Theme ───────────────��───────────────────────────────────────────────────���
ThemeData buildCyberpunkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: ColorScheme.dark(
      primary: kCyan,
      secondary: kPink,
      surface: kSurface,
      error: kNeonRed,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kCyan,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: kCyan,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        shadows: [Shadow(color: kCyan, blurRadius: 8)],
      ),
      iconTheme: const IconThemeData(color: kCyan),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kSurface,
      selectedItemColor: kCyan,
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
        backgroundColor: kCyan,
        foregroundColor: kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle:
            const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kCyan,
        side: const BorderSide(color: kCyan),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kCyan),
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
        borderSide: const BorderSide(color: kCyan, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: kText),
      bodyLarge: TextStyle(color: kText),
      bodySmall: TextStyle(color: kTextDim),
      titleMedium: TextStyle(color: kText, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: kText, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: kCyan, fontWeight: FontWeight.bold, letterSpacing: 0.5),
    ),
    dividerTheme: const DividerThemeData(color: kBorderDim),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kCyan : kSurface),
      checkColor: WidgetStateProperty.all(kBg),
      side: const BorderSide(color: kCyan),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kCard,
      contentTextStyle: const TextStyle(color: kText),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: kCyan, width: 1)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kCyan, width: 1)),
    ),
  );
}
