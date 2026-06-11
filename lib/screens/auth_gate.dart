import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';
import 'onboarding_screen.dart';

/// App entry gate: requires a Google sign-in, then a completed local profile
/// (name + birthday + body) before the main app. Routes:
///   signed out         → WelcomeScreen (sign in with Google)
///   signed in, no info  → OnboardingScreen
///   signed in + profile → HomeScreen
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Load the local profile so we can tell "needs onboarding" from "loading".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ProfileProvider>();
      if (!p.loaded) p.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isSignedIn) return const WelcomeScreen();

    final profile = context.watch<ProfileProvider>();
    if (!profile.loaded) {
      return const Scaffold(
        backgroundColor: AppColors.surface0,
        body: Center(child: CircularProgressIndicator(color: AppColors.healthRed)),
      );
    }
    if (auth.needsProfileSetup || !profile.hasProfile) {
      return const OnboardingScreen();
    }
    return const HomeScreen();
  }
}
