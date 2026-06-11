import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Motion tokens for the athletic-editorial design system.
///
/// Springs over curves: the default animation primitive is a
/// [SpringSimulation] built from [standardSpring]; `Curves.easeInOut` is
/// banned. Fixed-duration values exist only for transitions that cannot take
/// a simulation (opacity fades, the section sweep, the number ticker).
/// Source of truth: design/system.md.
class AppMotion {
  AppMotion._();

  // ── Springs ─────────────────────────────────────────────────────────────

  /// Default spring for movement and scale.
  static const SpringDescription standardSpring =
      SpringDescription(mass: 1, stiffness: 320, damping: 26);

  /// Underdamped variant for progress fills and reveals that should
  /// overshoot slightly before settling.
  static const SpringDescription overshootSpring =
      SpringDescription(mass: 1, stiffness: 320, damping: 18);

  /// Builds a 0→1 [SpringSimulation] ready for `AnimationController.animateWith`.
  static SpringSimulation springSimulation({
    SpringDescription spring = standardSpring,
    double from = 0,
    double to = 1,
    double velocity = 0,
  }) =>
      SpringSimulation(spring, from, to, velocity);

  // ── Durations & curves (non-spring transitions only) ────────────────────

  /// Enter transitions (fades, sheet reveals).
  static const Duration enter = Duration(milliseconds: 220);

  /// Exit transitions.
  static const Duration exit = Duration(milliseconds: 160);

  /// Number "ticker" — TweenAnimationBuilder<double> over stat changes.
  static const Duration numberTicker = Duration(milliseconds: 600);
  static const Curve numberTickerCurve = Curves.easeOutCubic;

  /// Progress fills (rings, bars) — pair with [overshootSpring].
  static const Duration progressFill = Duration(milliseconds: 800);

  /// Gap between sibling reveals in staggered choreography (50–80ms band).
  static const Duration staggerStep = Duration(milliseconds: 60);

  /// The horizontal accent sweep on section (tab) change.
  static const Duration sweepDuration = Duration(milliseconds: 220);

  // ── Focus / selection glow ──────────────────────────────────────────────

  /// The only sanctioned glow: accent at 18% alpha, blur 12. Used with a
  /// 1.5px accent border on focused / selected / active elements. Never a
  /// solid accent fill.
  static List<BoxShadow> accentGlow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 12,
        ),
      ];

  /// Border width for focused / selected / active elements.
  static const double focusBorderWidth = 1.5;
}
