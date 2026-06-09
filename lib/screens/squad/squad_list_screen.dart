import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// The Squad tab when signed in. Phase 1: confirms sign-in and shows the empty
/// state. Create/Join wiring and the real squad list arrive in Phase 2.
class SquadListScreen extends StatelessWidget {
  const SquadListScreen({super.key});

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create & join squads land in the next update')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.appUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY SQUADS'),
        titleTextStyle: const TextStyle(
            color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4,
            shadows: [Shadow(color: kNavy, blurRadius: 6)]),
        iconTheme: const IconThemeData(color: kNavy),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Signed-in identity card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(kNavy),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kCard,
                backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                    ? const Icon(Icons.person, color: kNavy)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.displayName ?? 'Athlete',
                      style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('Signed in with Google', style: TextStyle(color: kTextDim, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 40),
          const Icon(Icons.groups_outlined, color: kNavy, size: 56),
          const SizedBox(height: 12),
          const Center(
            child: Text('No squads yet', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('Create a squad or join one with a 6-digit code.',
                style: TextStyle(color: kTextDim, fontSize: 13)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _comingSoon(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy, foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add),
            label: const Text('CREATE SQUAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _comingSoon(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: kNavy, side: const BorderSide(color: kNavy),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.tag),
            label: const Text('JOIN WITH CODE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ]),
      ),
    );
  }
}
