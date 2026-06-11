import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';

/// Shown in the Squad tab when signed out. The rest of the app works without
/// signing in — only Squad requires it. Centered hero: flame mark, displayL
/// headline, bodyL sub, full-width squadBlue outlined Google sign-in.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: const SectionAppBar(
        title: 'Squads',
        caption: 'Accountability',
        accent: AppColors.squadBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.s24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(LucideIcons.flame, color: AppColors.healthRed, size: 64),
          const SizedBox(height: Spacing.s24),
          Text(
            'Track together, win together',
            textAlign: TextAlign.center,
            style: AppText.displayL,
          ),
          const SizedBox(height: Spacing.s12),
          Text(
            'Team up with up to 10 friends, set your own daily goals, and keep '
            'each other on track. Only your daily progress is shared — your '
            'meals and workouts stay on your device.',
            textAlign: TextAlign.center,
            style: AppText.bodyL.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Spacing.s32),
          if (auth.error != null) ...[
            Text(
              auth.error!,
              textAlign: TextAlign.center,
              style: AppText.bodyS.copyWith(color: AppColors.statusMissed),
            ),
            const SizedBox(height: Spacing.s12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  auth.isBusy ? null : () => context.read<AuthProvider>().signIn(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.squadBlue,
                side: const BorderSide(
                    color: AppColors.squadBlue,
                    width: AppMotion.focusBorderWidth),
                padding: const EdgeInsets.symmetric(vertical: Spacing.s12),
              ),
              icon: auth.isBusy
                  ? const ShimmerPlaceholder(
                      width: 18, height: 18, radius: AppRadius.pill)
                  : const Icon(LucideIcons.logIn, size: 18),
              label: Text(auth.isBusy ? 'Signing in…' : 'Sign in with Google'),
            ),
          ),
        ]),
      ),
    );
  }
}
