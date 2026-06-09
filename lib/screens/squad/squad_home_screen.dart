import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/squad_service.dart';
import '../../theme/app_theme.dart';

/// Single-squad screen. Phase 2: identity (name, members, invite code + owner
/// regenerate). The Today / Leaderboard / Settings tabs arrive in later phases.
class SquadHomeScreen extends StatelessWidget {
  final String squadId;
  const SquadHomeScreen({super.key, required this.squadId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kNavy),
        titleTextStyle: const TextStyle(color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4),
        title: const Text('SQUAD'),
      ),
      body: StreamBuilder<Squad?>(
        stream: service.watchSquad(squadId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kNavy));
          }
          final squad = snap.data;
          if (squad == null) {
            return const Center(child: Text('Squad not found', style: TextStyle(color: kTextDim)));
          }
          final isOwner = myUid != null && squad.isOwner(myUid);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(squad.name, style: const TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${squad.memberCount}/${Squad.maxMembers} members${isOwner ? '  •  you own this squad' : ''}',
                  style: const TextStyle(color: kTextDim, fontSize: 13)),
              const SizedBox(height: 20),
              _inviteCard(context, service, squad, isOwner),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: neonBox(kBorderDim),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('COMING SOON', style: TextStyle(color: kTextDim, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
                  SizedBox(height: 8),
                  Text('• Set your daily goal & privacy (next update)\n'
                      '• Today: everyone\'s progress\n'
                      '• Leaderboard & streaks\n'
                      '• Reactions 🔥 💪 👏',
                      style: TextStyle(color: kTextDim, fontSize: 13, height: 1.6)),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _inviteCard(BuildContext context, SquadService service, Squad squad, bool isOwner) {
    final expired = squad.inviteExpired;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: neonBox(kNavy),
      child: Column(children: [
        Text('INVITE CODE', style: neonLabel(kNavy, size: 12)),
        const SizedBox(height: 8),
        Text(squad.inviteCode,
            style: TextStyle(
                color: expired ? kTextDim : kWhite,
                fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 6)),
        const SizedBox(height: 4),
        Text(expired ? 'Expired — regenerate to invite' : 'Valid for 7 days from creation',
            style: TextStyle(color: expired ? kNeonRed : kTextDim, fontSize: 11)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: 'Join my squad "${squad.name}" — code ${squad.inviteCode}'));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite copied')));
              },
              style: OutlinedButton.styleFrom(foregroundColor: kNavy, side: const BorderSide(color: kNavy)),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('COPY'),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await service.regenerateInviteCode(squad.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New code generated — old one disabled')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: kWhite),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('NEW CODE'),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
