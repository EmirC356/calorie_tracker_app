import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';

/// Shown once after the first Google sign-in to confirm the display name and
/// avatar. Defaults come from the Google account. Custom avatar upload would
/// need Firebase Storage and is deferred; for now the avatar is the Google
/// photo. Reachable later via Squad settings to edit the name.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final appUser = context.read<AuthProvider>().appUser;
    _name = TextEditingController(text: appUser?.displayName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AuthProvider>().saveProfile(_name.text);
    // needsProfileSetup flips false → the Squad tab rebuilds to the list.
  }

  @override
  Widget build(BuildContext context) {
    final appUser = context.watch<AuthProvider>().appUser;
    return Scaffold(
      appBar: const SectionAppBar(
        title: 'Set up profile',
        caption: 'Squads',
        accent: AppColors.squadBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.s24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: Spacing.s12),
          Center(
            child: MemberAvatar(
              photoURL:
                  (appUser?.photoURL?.isNotEmpty ?? false) ? appUser!.photoURL : null,
              displayName: appUser?.displayName ?? 'Athlete',
              size: 88,
            ),
          ),
          const SizedBox(height: Spacing.s24),
          Text('DISPLAY NAME', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          TextField(
            controller: _name,
            style: AppText.bodyL,
            decoration: const InputDecoration(hintText: 'How squadmates see you'),
          ),
          const SizedBox(height: Spacing.s8),
          Text(
            'This is how you appear to your squads. You can change it later in Squad settings.',
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Spacing.s24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.squadBlue,
              foregroundColor: AppColors.surface0,
              padding: const EdgeInsets.symmetric(vertical: Spacing.s12),
            ),
            child: Text(_saving ? 'Saving…' : 'Continue'),
          ),
        ]),
      ),
    );
  }
}
