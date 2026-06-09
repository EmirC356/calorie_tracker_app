import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// Shown in the Squad tab when signed out. The rest of the app works without
/// signing in — only Squad requires it.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQUAD'),
        titleTextStyle: const TextStyle(
            color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4,
            shadows: [Shadow(color: kNavy, blurRadius: 6)]),
        iconTheme: const IconThemeData(color: kNavy),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: neonBox(kNavy),
            child: const Icon(Icons.groups, color: kNavy, size: 56),
          ),
          const SizedBox(height: 24),
          Text('SQUAD ACCOUNTABILITY', style: neonLabel(kNavy, size: 18)),
          const SizedBox(height: 10),
          const Text(
            'Team up with up to 10 friends, set your own daily goals, and keep '
            'each other on track. Only your daily progress is shared — your '
            'meals and workouts stay on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextDim, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          if (auth.error != null) ...[
            Text(auth.error!, style: const TextStyle(color: kNeonRed, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: auth.isBusy ? null : () => context.read<AuthProvider>().signIn(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: kWhite,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: auth.isBusy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                  : const Icon(Icons.login),
              label: Text(auth.isBusy ? 'SIGNING IN...' : 'SIGN IN WITH GOOGLE',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ]),
      ),
    );
  }
}
