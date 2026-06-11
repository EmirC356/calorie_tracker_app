/// Spacing and radius tokens for the athletic-editorial design system.
///
/// The spacing scale is closed: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 / 64.
/// No arbitrary paddings outside this list. Radii: 0 for data lines, 8 for
/// chips and small buttons, 12 for cards, 16 for sheets, 999 for pills and
/// avatars. Source of truth: design/system.md.
class Spacing {
  Spacing._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;
}

/// Radius tokens. See [Spacing] for the scale rationale.
class AppRadius {
  AppRadius._();

  /// Data lines (timelines, chart axes) — square.
  static const double r0 = 0;

  /// Chips, small buttons.
  static const double r8 = 8;

  /// Cards.
  static const double r12 = 12;

  /// Sheets, dialogs, popovers.
  static const double r16 = 16;

  /// Pills, avatars.
  static const double pill = 999;
}
