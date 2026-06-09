import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../models/squad_goal_suggestion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';
import 'create_squad_screen.dart';
import 'join_squad_screen.dart';
import 'squad_home_screen.dart';
import 'goal_inbox_screen.dart';

/// The Squad tab when signed in: the user's squads (live) + create/join.
class SquadListScreen extends StatefulWidget {
  const SquadListScreen({super.key});

  @override
  State<SquadListScreen> createState() => _SquadListScreenState();
}

class _SquadListScreenState extends State<SquadListScreen> {
  @override
  void initState() {
    super.initState();
    // Bind the squads stream to the current user (with name/photo for the
    // denormalized member docs).
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid;
    final user = auth.appUser;
    final squads = context.read<SquadProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => squads.bind(
          uid,
          displayName: user?.displayName ?? 'Athlete',
          photoURL: user?.photoURL,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final squadProvider = context.watch<SquadProvider>();
    final user = auth.appUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MY SQUADS'),
        titleTextStyle: const TextStyle(
            color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4,
            shadows: [Shadow(color: kNavy, blurRadius: 6)]),
        iconTheme: const IconThemeData(color: kNavy),
        actions: [
          if (auth.firebaseUser?.uid != null)
            _InboxBadge(uid: auth.firebaseUser!.uid),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kNavy,
        onRefresh: () async => squadProvider.bind(auth.firebaseUser?.uid),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Identity card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: neonBox(kNavy),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: kCard,
                  backgroundImage: (user?.photoURL?.isNotEmpty ?? false) ? NetworkImage(user!.photoURL!) : null,
                  child: (user?.photoURL?.isEmpty ?? true) ? const Icon(Icons.person, color: kNavy) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(user?.displayName ?? 'Athlete',
                    style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold))),
              ]),
            ),
            const SizedBox(height: 16),

            if (squadProvider.loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: kNavy)))
            else if (squadProvider.error != null)
              _errorBox(squadProvider.error!)
            else if (squadProvider.squads.isEmpty)
              _emptyState()
            else
              ...squadProvider.squads.map((s) => _squadCard(s, auth.firebaseUser?.uid)),

            const SizedBox(height: 8),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _squadCard(Squad s, String? uid) {
    final isOwner = uid != null && s.isOwner(uid);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => SquadHomeScreen(squadId: s.id))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: neonBox(kNavy),
          child: Row(children: [
            const Icon(Icons.groups, color: kNavy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${s.memberCount}/${Squad.maxMembers} members${isOwner ? '  •  owner' : ''}',
                    style: const TextStyle(color: kTextDim, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: kTextDim),
          ]),
        ),
      ),
    );
  }

  Widget _emptyState() => Column(children: [
        const SizedBox(height: 24),
        const Icon(Icons.groups_outlined, color: kNavy, size: 52),
        const SizedBox(height: 10),
        const Text('No squads yet', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Create a squad or join one with a 6-digit code.',
            style: TextStyle(color: kTextDim, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 16),
      ]);

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(14),
        decoration: neonBox(kNeonRed),
        child: Text('Couldn\'t load squads: $msg', style: const TextStyle(color: kNeonRed, fontSize: 12)),
      );

  Widget _actions() => Column(children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSquadScreen())),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy, foregroundColor: kWhite,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.add),
          label: const Text('CREATE SQUAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinSquadScreen())),
          style: OutlinedButton.styleFrom(
            foregroundColor: kNavy, side: const BorderSide(color: kNavy),
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.tag),
          label: const Text('JOIN WITH CODE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ]);
}

/// AppBar action: opens the goal inbox, with a live pending-count badge.
class _InboxBadge extends StatelessWidget {
  final String uid;
  const _InboxBadge({required this.uid});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    return StreamBuilder<List<SquadGoalSuggestion>>(
      stream: service.streamPendingSuggestionsForMe(uid),
      builder: (_, snap) {
        final count = snap.data?.length ?? 0;
        return Stack(alignment: Alignment.center, children: [
          IconButton(
            tooltip: 'Goal inbox',
            icon: const Icon(Icons.inbox),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const GoalInboxScreen())),
          ),
          if (count > 0)
            Positioned(
              right: 6,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: kNeonRed, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kWhite, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
        ]);
      },
    );
  }
}
