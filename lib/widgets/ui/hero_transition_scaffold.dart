import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

/// Scaffold wrapper for screens entered via shared-element (Hero) navigation.
///
/// Push detail screens with [HeroTransitionScaffold.route] — a fade + subtle
/// scale route (no default MaterialPageRoute slide) that Hero flights animate
/// through. Convention: the tapped card and the detail screen wrap the shared
/// element in `Hero(tag: <stable id, e.g. meal.id>)`.
class HeroTransitionScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  const HeroTransitionScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  /// Fade + 0.98→1 scale page route; Hero animations fly above it.
  static Route<T> route<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppMotion.enter,
      reverseTransitionDuration: AppMotion.exit,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
    );
  }
}
