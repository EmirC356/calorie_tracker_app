import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'sign_in_screen.dart';
import 'profile_setup_screen.dart';
import 'squad_list_screen.dart';

/// Routes the Squad tab to the right screen based on auth state. Kept separate
/// so the rest of the app never touches AuthProvider (lazy-created here).
class SquadTab extends StatelessWidget {
  const SquadTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isSignedIn) return const SignInScreen();
    if (auth.needsProfileSetup) return const ProfileSetupScreen();
    return const SquadListScreen();
  }
}
