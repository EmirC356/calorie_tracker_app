import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../models/squad_member.dart';
import '../../models/squad_pause.dart';
import '../../models/squad_group_goal.dart';
import '../../models/date_helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/squad_service.dart';
import '../../services/pause_service.dart';
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
          if (isOwner) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _createGroupGoalDialog(context, service, squad.id, myUid),
              style: OutlinedButton.styleFrom(foregroundColor: kNavy, side: const BorderSide(color: kNavy), minimumSize: const Size.fromHeight(46)),
              icon: const Icon(Icons.flag, size: 18),
              label: const Text('NEW GROUP GOAL'),
            ),
          ],
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
          const SizedBox(height: 16),
          // Notifications mute
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: neonBox(kBorderDim),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kNavy,
              title: const Text('Mute notifications', style: TextStyle(color: kText, fontSize: 14)),
              subtitle: const Text('No pushes from this squad (goal hits, nudges, summary)',
                  style: TextStyle(color: kTextDim, fontSize: 11)),
              value: me.muted,
              onChanged: (v) => service.updateMuted(squad.id, myUid, v),
            ),
          ),
          const SizedBox(height: 16),
          _pauseCard(context, service, squad.id, myUid, me),
        ]);
      },
    );
  }

  Widget _pauseCard(BuildContext context, SquadService service, String squadId, String myUid, SquadMember me) {
    final paused = me.pause.isCurrentlyPaused(DateTime.now());
    const teal = Color(0xFF4CC38A);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kBorderDim),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PAUSE / VACATION', style: neonLabel(kNavy, size: 12)),
        const SizedBox(height: 4),
        const Text('Freeze your streak and skip ghost/streak alerts while you\'re off. '
            'Max 21 days at a time, 60 days a year.',
            style: TextStyle(color: kTextDim, fontSize: 11)),
        const SizedBox(height: 10),
        if (paused) ...[
          Row(children: [
            const Text('🌴  ', style: TextStyle(fontSize: 18)),
            Expanded(child: Text('Paused til ${_fmtDate(me.pause.until!)}',
                style: const TextStyle(color: teal, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 4),
          Text('${me.pause.daysUsedThisYear}/60 pause days used this year',
              style: const TextStyle(color: kTextDim, fontSize: 11)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await PauseService(squad: service).resumePause(squadId: squadId, uid: myUid);
              messenger.showSnackBar(const SnackBar(content: Text('Welcome back — your streak resumes 💪')));
            },
            style: OutlinedButton.styleFrom(foregroundColor: kNavy, side: const BorderSide(color: kNavy)),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('RESUME NOW'),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: () => _startPause(context, service, squadId, myUid),
            style: OutlinedButton.styleFrom(foregroundColor: teal, side: const BorderSide(color: teal)),
            icon: const Icon(Icons.beach_access, size: 18),
            label: const Text('PAUSE THIS SQUAD'),
          ),
      ]),
    );
  }

  Future<void> _startPause(BuildContext context, SquadService service, String squadId, String myUid) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 21)),
      helpText: 'Paused until (inclusive)',
    );
    if (until == null || !context.mounted) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Pause reason (optional)', style: TextStyle(color: kText, fontSize: 16)),
        content: TextField(
          controller: reasonCtrl, maxLength: 60, style: const TextStyle(color: kText),
          decoration: const InputDecoration(hintText: 'e.g. traveling'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('PAUSE')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final plan = await PauseService(squad: service).declarePause(
      squadId: squadId, uid: myUid, until: until, reason: reasonCtrl.text, now: now);
    final msg = switch (plan.validation) {
      PauseValidation.ok => 'Paused til ${_fmtDate(until)} — streak frozen 🌴',
      PauseValidation.alreadyPaused => 'You\'re already paused for this squad.',
      PauseValidation.yearlyCapReached => 'That would exceed your 60 pause days this year.',
      PauseValidation.windowTooLong => 'Pauses can be at most 21 days.',
      PauseValidation.endInPast => 'Pick a date in the future.',
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  Future<void> _createGroupGoalDialog(BuildContext context, SquadService service, String squadId, String ownerUid) async {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    var metric = 'mealsLoggedTotal';
    const metricLabels = {
      'mealsLoggedTotal': 'Meals logged (squad total)',
      'exerciseSessionsTotal': 'Workout sessions (squad total)',
    };
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: kSurface,
          title: const Text('New group goal', style: TextStyle(color: kText, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, maxLength: 40, style: const TextStyle(color: kText),
                decoration: const InputDecoration(hintText: 'e.g. 50 workouts this month')),
            DropdownButton<String>(
              isExpanded: true, value: metric, dropdownColor: kCard,
              style: const TextStyle(color: kText, fontSize: 13),
              items: [for (final e in metricLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => metric = v ?? metric),
            ),
            TextField(controller: targetCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: kText),
                decoration: const InputDecoration(hintText: 'Target (e.g. 50)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CREATE')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final target = double.tryParse(targetCtrl.text.trim());
    if (titleCtrl.text.trim().isEmpty || target == null || target <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a title and a positive target')));
      return;
    }
    final now = DateTime.now();
    await service.createGroupGoal(
      squadId,
      SquadGroupGoal(
        id: '', title: titleCtrl.text.trim(), metric: metric, target: target,
        startDate: ymd(now), endDate: ymd(now.add(const Duration(days: 30))), createdBy: ownerUid),
    );
    messenger.showSnackBar(const SnackBar(content: Text('Group goal created 🎯')));
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
