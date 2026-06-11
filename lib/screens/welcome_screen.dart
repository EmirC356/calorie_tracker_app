import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ui/ui.dart';

/// The app's sign-in gate: Lanabuzer requires a Google sign-in before use.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(LucideIcons.flame, color: AppColors.healthRed, size: 72),
            const SizedBox(height: Spacing.s16),
            Text('Lanabuzer', textAlign: TextAlign.center, style: AppText.displayL),
            const SizedBox(height: Spacing.s12),
            Text(
              'Track your meals, workouts and goals — and keep each other on track '
              'with your squad. Sign in with Google to get started.',
              textAlign: TextAlign.center,
              style: AppText.bodyL.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: Spacing.s32),
            if (auth.error != null) ...[
              Text(auth.error!,
                  textAlign: TextAlign.center,
                  style: AppText.bodyS.copyWith(color: AppColors.statusMissed)),
              const SizedBox(height: Spacing.s12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: auth.isBusy ? null : () => context.read<AuthProvider>().signIn(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.healthRed,
                  side: const BorderSide(color: AppColors.healthRed, width: AppMotion.focusBorderWidth),
                  padding: const EdgeInsets.symmetric(vertical: Spacing.s12),
                ),
                icon: auth.isBusy
                    ? const ShimmerPlaceholder(width: 18, height: 18, radius: AppRadius.pill)
                    : const Icon(LucideIcons.logIn, size: 18),
                label: Text(auth.isBusy ? 'Signing in…' : 'Sign in with Google'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
