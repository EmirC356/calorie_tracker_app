import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

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
    final photo = appUser?.photoURL;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SET UP PROFILE'),
        automaticallyImplyLeading: false,
        titleTextStyle: const TextStyle(
            color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4,
            shadows: [Shadow(color: kNavy, blurRadius: 6)]),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: kCard,
              backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
              child: (photo == null || photo.isEmpty)
                  ? const Icon(Icons.person, color: kNavy, size: 44)
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          Text('DISPLAY NAME', style: neonLabel(kNavy, size: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            style: const TextStyle(color: kText),
            decoration: const InputDecoration(hintText: 'How squadmates see you'),
          ),
          const SizedBox(height: 8),
          const Text('This is how you appear to your squads. You can change it later in Squad settings.',
              style: TextStyle(color: kTextDim, fontSize: 12)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_saving ? 'SAVING...' : 'CONTINUE',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ]),
      ),
    );
  }
}
