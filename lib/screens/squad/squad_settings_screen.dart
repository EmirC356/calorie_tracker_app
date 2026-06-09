import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../models/squad_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/squad_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/squad/goal_summary.dart';
import 'goal_editor_screen.dart';

/// The "Settings" tab of a squad: my goal, my sharing level, invite, members,
/// and leave/delete + owner controls (rename, kick, transfer).
class SquadSettingsScreen extends StatelessWidget {
  final String squadId;
  const SquadSettingsScreen({super.key, required this.squadId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;
    if (myUid == null) return const SizedBox.shrink();

    return StreamBuilder<Squad?>(
      stream: service.watchSquad(squadId),
      builder: (context, snap) {
        final squad = snap.data;
        if (squad == null) {
          return snap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator(color: kNavy))
              : const Center(child: Text('Squad not found', style: TextStyle(color: kTextDim)));
        }
        final isOwner = squad.isOwner(myUid);
        return ListView(padding: const EdgeInsets.all(16), children: [
          _header(context, service, squad, isOwner),
          const SizedBox(height: 16),
          _inviteCard(context, service, squad, isOwner),
          const SizedBox(height: 16),
          _myGoalAndSharing(context, service, squad, myUid),
          const SizedBox(height: 16),
          _membersSection(context, service, squad, myUid, isOwner),
          const SizedBox(height: 24),
          _dangerZone(context, service, squad, myUid, isOwner),
        ]);
      },
    );
  }

  Widget _header(BuildContext context, SquadService service, Squad squad, bool isOwner) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(squad.name, style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.bold)),
          Text('${squad.memberCount}/${Squad.maxMembers} members${isOwner ? '  •  you own this' : ''}',
              style: const TextStyle(color: kTextDim, fontSize: 12)),
        ]),
      ),
      if (isOwner)
        IconButton(
          icon: const Icon(Icons.edit, color: kNavy),
          tooltip: 'Rename squad',
          onPressed: () => _renameDialog(context, service, squad),
        ),
    ]);
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
            style: TextStyle(color: expired ? kTextDim : kWhite, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6)),
        Text(expired ? 'Expired — regenerate to invite' : 'Valid 7 days from creation',
            style: TextStyle(color: expired ? kNeonRed : kTextDim, fontSize: 11)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Join my squad "${squad.name}" — code ${squad.inviteCode}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite copied')));
            },
            style: OutlinedButton.styleFrom(foregroundColor: kNavy, side: const BorderSide(color: kNavy)),
            icon: const Icon(Icons.copy, size: 18), label: const Text('COPY'),
          )),
          if (isOwner) ...[
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                await service.regenerateInviteCode(squad.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New code generated')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: kWhite),
              icon: const Icon(Icons.refresh, size: 18), label: const Text('NEW CODE'),
            )),
          ],
        ]),
      ]),
    );
  }

  Widget _myGoalAndSharing(BuildContext context, SquadService service, Squad squad, String myUid) {
    return StreamBuilder<SquadMember?>(
      stream: service.watchMember(squad.id, myUid),
      builder: (context, snap) {
        final me = snap.data ?? const SquadMember(uid: '');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // My goal
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(kBorderDim),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MY DAILY GOAL', style: neonLabel(kNavy, size: 12)),
              const SizedBox(height: 10),
              GoalSummary(goal: me.goal, fontSize: 15),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final updated = await Navigator.push<dynamic>(context,
                      MaterialPageRoute(builder: (_) => GoalEditorScreen(initial: me.goal)));
                  if (updated != null) await service.updateGoal(squad.id, myUid, updated);
                },
                style: OutlinedButton.styleFrom(foregroundColor: kNavy, side: const BorderSide(color: kNavy)),
                icon: const Icon(Icons.edit, size: 18),
                label: Text(me.goal.isEmpty ? 'SET GOAL' : 'EDIT GOAL'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // My sharing level
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(kBorderDim),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WHAT THIS SQUAD SEES', style: neonLabel(kNavy, size: 12)),
              const SizedBox(height: 4),
              const Text('Your goal is always visible. This controls meal/exercise detail.',
                  style: TextStyle(color: kTextDim, fontSize: 11)),
              const SizedBox(height: 10),
              _sharingToggle(context, service, squad.id, myUid, me.sharingLevel),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _sharingToggle(BuildContext context, SquadService service, String squadId, String myUid, SharingLevel current) {
    const labels = {
      SharingLevel.status: 'Status only',
      SharingLevel.totals: 'Status + totals',
      SharingLevel.full: 'Everything',
    };
    return Column(
      children: SharingLevel.values.map((lvl) {
        final sel = lvl == current;
        return GestureDetector(
          onTap: () => service.updateSharingLevel(squadId, myUid, lvl),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? kNavy.withValues(alpha: 0.18) : kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? kNavy : kBorderDim),
            ),
            child: Row(children: [
              Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? kNavy : kTextDim, size: 18),
              const SizedBox(width: 10),
              Text(labels[lvl]!, style: TextStyle(color: sel ? kText : kTextDim, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _membersSection(BuildContext context, SquadService service, Squad squad, String myUid, bool isOwner) {
    return StreamBuilder<List<SquadMember>>(
      stream: service.watchMembers(squad.id),
      builder: (context, snap) {
        final members = snap.data ?? const [];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: neonBox(kBorderDim),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MEMBERS', style: neonLabel(kNavy, size: 12)),
            const SizedBox(height: 8),
            ...members.map((m) => _memberRow(context, service, squad, m, myUid, isOwner)),
          ]),
        );
      },
    );
  }

  Widget _memberRow(BuildContext context, SquadService service, Squad squad, SquadMember m, String myUid, bool isOwner) {
    final isMe = m.uid == myUid;
    final isThisOwner = squad.isOwner(m.uid);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        CircleAvatar(
          radius: 18, backgroundColor: kSurface,
          backgroundImage: (m.photoURL?.isNotEmpty ?? false) ? NetworkImage(m.photoURL!) : null,
          child: (m.photoURL?.isEmpty ?? true) ? const Icon(Icons.person, color: kNavy, size: 18) : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(m.displayName, style: const TextStyle(color: kText, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (isThisOwner) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.star, color: kNavy, size: 14)),
            if (isMe) const Padding(padding: EdgeInsets.only(left: 6), child: Text('you', style: TextStyle(color: kTextDim, fontSize: 11))),
          ]),
          GoalSummary(goal: m.goal, fontSize: 11),
        ])),
        if (isOwner && !isMe)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: kTextDim),
            color: kCard,
            onSelected: (v) async {
              if (v == 'kick') {
                final ok = await _confirm(context, 'Remove ${m.displayName}?', 'They\'ll be removed from this squad.');
                if (ok) await service.kickMember(squad.id, m.uid);
              } else if (v == 'transfer') {
                final ok = await _confirm(context, 'Make ${m.displayName} the owner?', 'You\'ll no longer own this squad.');
                if (ok) await service.transferOwnership(squad.id, m.uid);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'transfer', child: Text('Make owner', style: TextStyle(color: kText))),
              PopupMenuItem(value: 'kick', child: Text('Remove', style: TextStyle(color: kNeonRed))),
            ],
          ),
      ]),
    );
  }

  Widget _dangerZone(BuildContext context, SquadService service, Squad squad, String myUid, bool isOwner) {
    if (isOwner) {
      return OutlinedButton.icon(
        onPressed: () async {
          final ok = await _confirm(context, 'Delete "${squad.name}"?', 'This permanently deletes the squad for everyone.');
          if (ok) {
            await service.deleteSquad(squad.id);
            if (context.mounted) Navigator.pop(context);
          }
        },
        style: OutlinedButton.styleFrom(foregroundColor: kNeonRed, side: const BorderSide(color: kNeonRed), minimumSize: const Size.fromHeight(48)),
        icon: const Icon(Icons.delete_outline),
        label: const Text('DELETE SQUAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      );
    }
    return OutlinedButton.icon(
      onPressed: () async {
        final ok = await _confirm(context, 'Leave "${squad.name}"?', 'You can rejoin later with an invite code.');
        if (ok) {
          await service.leaveSquad(squad.id, myUid);
          if (context.mounted) Navigator.pop(context);
        }
      },
      style: OutlinedButton.styleFrom(foregroundColor: kNeonRed, side: const BorderSide(color: kNeonRed), minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.exit_to_app),
      label: const Text('LEAVE SQUAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Future<void> _renameDialog(BuildContext context, SquadService service, Squad squad) async {
    final ctrl = TextEditingController(text: squad.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Rename squad', style: TextStyle(color: kText)),
        content: TextField(controller: ctrl, style: const TextStyle(color: kText), maxLength: 30),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('SAVE')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await service.renameSquad(squad.id, name);
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(title, style: const TextStyle(color: kText, fontSize: 16)),
        content: Text(body, style: const TextStyle(color: kTextDim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRM', style: TextStyle(color: kNeonRed))),
        ],
      ),
    );
    return res ?? false;
  }
}
