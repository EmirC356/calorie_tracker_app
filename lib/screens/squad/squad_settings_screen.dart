import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/squad.dart';
import '../../models/squad_member.dart';
import '../../models/squad_pause.dart';
import '../../models/squad_group_goal.dart';
import '../../models/date_helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/squad_service.dart';
import '../../services/pause_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'squad_notifications_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/member_avatar.dart';
import '../../widgets/ui/shimmer_placeholder.dart';
import '../../widgets/squad/goal_summary.dart';
import '../../widgets/squad/presence_indicator.dart';
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
              ? ListView(
                  padding: const EdgeInsets.all(Spacing.s16),
                  children: const [
                    ShimmerPlaceholder.card(height: 96),
                    SizedBox(height: Spacing.s12),
                    ShimmerPlaceholder.card(height: 160),
                  ],
                )
              : Center(
                  child: Text('Squad not found',
                      style: AppText.bodyM
                          .copyWith(color: AppColors.textSecondary)));
        }
        final isOwner = squad.isOwner(myUid);
        // The squad name + member count live in the AppBar subtitle now.
        return ListView(padding: const EdgeInsets.all(Spacing.s16), children: [
          _inviteCard(context, service, squad, isOwner),
          const SizedBox(height: Spacing.s24),
          _myGoalAndSharing(context, service, squad, myUid),
          const SizedBox(height: Spacing.s24),
          _membersSection(context, service, squad, myUid, isOwner),
          if (isOwner) ...[
            const SizedBox(height: Spacing.s16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _createGroupGoalDialog(context, service, squad.id, myUid),
                  style: _ownerBtn(),
                  icon: const Icon(LucideIcons.flag, size: 18),
                  label: const Text('Group goal'),
                ),
              ),
              const SizedBox(width: Spacing.s12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _renameDialog(context, service, squad),
                  style: _ownerBtn(),
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  label: const Text('Rename'),
                ),
              ),
            ]),
          ],
          const SizedBox(height: Spacing.s24),
          _dangerZone(context, service, squad, myUid, isOwner),
        ]);
      },
    );
  }

  ButtonStyle _ownerBtn() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.squadBlue,
        side: const BorderSide(color: AppColors.squadBlue, width: 1.5),
        minimumSize: const Size.fromHeight(46),
      );

  Widget _inviteCard(BuildContext context, SquadService service, Squad squad, bool isOwner) {
    final expired = squad.inviteExpired;
    return Column(children: [
      Text('INVITE CODE', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      Text(squad.inviteCode,
          style: AppText.displayL.copyWith(
              letterSpacing: 6,
              color: expired
                  ? AppColors.textTertiary
                  : AppColors.textPrimary)),
      Text(expired ? 'Expired — regenerate to invite' : 'Valid 7 days from creation',
          style: AppText.caption.copyWith(
              color: expired
                  ? AppColors.statusMissed
                  : AppColors.textTertiary)),
      const SizedBox(height: Spacing.s12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _inviteText(squad)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite copied')));
          },
          style: _ownerBtn(),
          icon: const Icon(LucideIcons.copy, size: 18),
          label: const Text('Copy'),
        )),
        const SizedBox(width: Spacing.s12),
        Expanded(child: OutlinedButton.icon(
          onPressed: () => Share.share(_inviteText(squad), subject: 'Join my squad'),
          style: _ownerBtn(),
          icon: const Icon(LucideIcons.share2, size: 18),
          label: const Text('Share'),
        )),
      ]),
      if (isOwner) ...[
        const SizedBox(height: Spacing.s12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await service.regenerateInviteCode(squad.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('New code generated')));
              }
            },
            style: _ownerBtn(),
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            label: const Text('Regenerate code'),
          ),
        ),
      ],
    ]);
  }

  Widget _goalModeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s8, horizontal: Spacing.s8),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          border: Border.all(
              color: active ? AppColors.squadBlue : AppColors.surface2,
              width: active ? 1.5 : 1),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: AppText.bodyS.copyWith(
                color: active ? AppColors.squadBlue : AppColors.textSecondary)),
      ),
    );
  }

  Widget _myGoalAndSharing(BuildContext context, SquadService service, Squad squad, String myUid) {
    return StreamBuilder<SquadMember?>(
      stream: service.watchMember(squad.id, myUid),
      builder: (context, snap) {
        final me = snap.data ?? const SquadMember(uid: '');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // My goal — inherited from profile Health Goals, or overridden here.
          Text('MY DAILY GOAL', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          Row(children: [
            Expanded(
              child: _goalModeChip('Same as profile', me.inheritedFromProfile, () {
                final snap = context.read<ProfileProvider>().profile?.healthGoalSnapshot;
                service.setGoalInheritance(squad.id, myUid, inherited: true, snapshot: snap);
              }),
            ),
            const SizedBox(width: Spacing.s8),
            Expanded(
              child: _goalModeChip('Override for this squad', !me.inheritedFromProfile, () {
                service.setGoalInheritance(squad.id, myUid, inherited: false, override: me.goal);
              }),
            ),
          ]),
          const SizedBox(height: Spacing.s12),
          GoalSummary(goal: me.effectiveGoal, fontSize: 15),
          const SizedBox(height: Spacing.s8),
          if (me.inheritedFromProfile)
            Text('Edit these in Profile → Health Goals.',
                style: AppText.bodyM.copyWith(color: AppColors.textSecondary))
          else
            OutlinedButton.icon(
              onPressed: () async {
                final updated = await Navigator.push<dynamic>(context,
                    MaterialPageRoute(builder: (_) => GoalEditorScreen(initial: me.goal)));
                if (updated != null) await service.updateGoal(squad.id, myUid, updated);
              },
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.squadBlue,
                  side: const BorderSide(color: AppColors.squadBlue, width: 1.5)),
              icon: const Icon(LucideIcons.pencil, size: 18),
              label: Text(me.goal.isEmpty ? 'Set goal' : 'Edit goal'),
            ),
          const SizedBox(height: Spacing.s24),
          // My sharing level
          Text('WHAT THIS SQUAD SEES', style: AppText.caption),
          const SizedBox(height: Spacing.s4),
          Text('Your goal is always visible. This controls meal/exercise detail.',
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: Spacing.s12),
          _sharingToggle(context, service, squad.id, myUid, me.sharingLevel),
          const SizedBox(height: Spacing.s16),
          // Notifications mute
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.squadBlue,
            title: Text('Mute notifications', style: AppText.bodyL),
            subtitle: Text('No pushes from this squad (goal hits, nudges, summary)',
                style:
                    AppText.bodyM.copyWith(color: AppColors.textSecondary)),
            value: me.muted,
            onChanged: (v) => service.updateMuted(squad.id, myUid, v),
          ),
          const Divider(color: AppColors.surface2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.bell,
                color: AppColors.textSecondary, size: 20),
            title: Text('Notification settings', style: AppText.bodyL),
            subtitle: Text('Push types + quiet hours (all squads)',
                style:
                    AppText.bodyM.copyWith(color: AppColors.textSecondary)),
            trailing: const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textTertiary),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SquadNotificationsScreen())),
          ),
          const SizedBox(height: Spacing.s16),
          _pauseCard(context, service, squad.id, myUid, me),
        ]);
      },
    );
  }

  Widget _pauseCard(BuildContext context, SquadService service, String squadId, String myUid, SquadMember me) {
    final paused = me.pause.isCurrentlyPaused(DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('PAUSE / VACATION', style: AppText.caption),
        const SizedBox(width: Spacing.s4),
        InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Pause / vacation'),
              content: const Text(
                  "Freeze your streak and skip ghost/streak alerts while you're off. "
                  'Max 21 days at a time, 60 days a year.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
              ],
            ),
          ),
          child: const Icon(LucideIcons.info, size: 14, color: AppColors.textTertiary),
        ),
      ]),
      const SizedBox(height: Spacing.s12),
      if (paused) ...[
        Row(children: [
          const Text('🌴  ', style: TextStyle(fontSize: 18)),
          Expanded(child: Text('Paused til ${_fmtDate(me.pause.until!)}',
              style: AppText.titleM
                  .copyWith(color: AppColors.statusPaused))),
        ]),
        const SizedBox(height: Spacing.s4),
        Text('${me.pause.daysUsedThisYear}/60 pause days used this year',
            style: AppText.tabular(AppText.caption)),
        const SizedBox(height: Spacing.s12),
        OutlinedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await PauseService(squad: service).resumePause(squadId: squadId, uid: myUid);
            messenger.showSnackBar(const SnackBar(content: Text('Welcome back — your streak resumes 💪')));
          },
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.squadBlue,
              side: const BorderSide(color: AppColors.squadBlue, width: 1.5)),
          icon: const Icon(LucideIcons.play, size: 18),
          label: const Text('Resume now'),
        ),
      ] else
        OutlinedButton.icon(
          onPressed: () => _startPause(context, service, squadId, myUid),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.statusPaused,
              side: const BorderSide(
                  color: AppColors.statusPaused, width: 1.5)),
          icon: const Icon(LucideIcons.palmtree, size: 18),
          label: const Text('Pause this squad'),
        ),
    ]);
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
        title: const Text('Pause reason (optional)'),
        content: TextField(
          controller: reasonCtrl, maxLength: 60,
          decoration: const InputDecoration(hintText: 'e.g. traveling'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pause')),
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

  static String _inviteText(Squad squad) =>
      'Join my squad "${squad.name}" on Lanabuzer — code ${squad.inviteCode}';

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
          title: const Text('New group goal'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, maxLength: 40,
                decoration: const InputDecoration(hintText: 'e.g. 50 workouts this month')),
            DropdownButton<String>(
              isExpanded: true, value: metric,
              dropdownColor: AppColors.surface3,
              style: AppText.bodyS,
              items: [for (final e in metricLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => metric = v ?? metric),
            ),
            TextField(controller: targetCtrl, keyboardType: TextInputType.number,
                style: AppText.tabular(AppText.bodyM),
                decoration: const InputDecoration(hintText: 'Target (e.g. 50)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
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

  /// Material 3 segmented control (keeps keyboard/focus + screen-reader
  /// semantics that hand-rolled pills would lose).
  Widget _sharingToggle(BuildContext context, SquadService service, String squadId, String myUid, SharingLevel current) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<SharingLevel>(
        segments: const [
          ButtonSegment(value: SharingLevel.status, label: Text('Status')),
          ButtonSegment(value: SharingLevel.totals, label: Text('Totals')),
          ButtonSegment(value: SharingLevel.full, label: Text('Everything')),
        ],
        selected: {current},
        showSelectedIcon: false,
        onSelectionChanged: (sel) => service.updateSharingLevel(squadId, myUid, sel.first),
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: AppColors.surface0,
          selectedBackgroundColor: AppColors.squadBlue,
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.surface2),
        ),
      ),
    );
  }

  Widget _membersSection(BuildContext context, SquadService service, Squad squad, String myUid, bool isOwner) {
    return StreamBuilder<List<SquadMember>>(
      stream: service.watchMembers(squad.id),
      builder: (context, snap) {
        final members = snap.data ?? const [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MEMBERS', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          ...members.map((m) => _memberRow(context, service, squad, m, myUid, isOwner)),
        ]);
      },
    );
  }

  Widget _memberRow(BuildContext context, SquadService service, Squad squad, SquadMember m, String myUid, bool isOwner) {
    final isMe = m.uid == myUid;
    final isThisOwner = squad.isOwner(m.uid);
    final canManage = isOwner && !isMe;
    return InkWell(
      onLongPress: canManage ? () => _ownerActions(context, service, squad, m) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
        child: Row(children: [
          MemberAvatar(
            photoURL: (m.photoURL?.isNotEmpty ?? false) ? m.photoURL : null,
            displayName: m.displayName,
            lastActiveDate: m.lastActivityAt,
            size: 36,
          ),
          const SizedBox(width: Spacing.s12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(m.displayName, style: AppText.titleM, overflow: TextOverflow.ellipsis)),
              if (isThisOwner)
                const Padding(
                    padding: EdgeInsets.only(left: Spacing.s8),
                    child: Icon(LucideIcons.crown, color: AppColors.squadBlue, size: 14)),
              if (isMe)
                Padding(
                    padding: const EdgeInsets.only(left: Spacing.s8),
                    child: Text('you', style: AppText.caption)),
            ]),
            const SizedBox(height: Spacing.s4),
            // Recency, not goal text — see who's actually showing up.
            PresenceIndicator(lastActive: m.lastActivityAt),
          ])),
          if (canManage)
            const Icon(LucideIcons.moreVertical, color: AppColors.textTertiary, size: 16),
        ]),
      ),
    );
  }

  /// Owner long-press menu: transfer ownership or remove a member.
  void _ownerActions(BuildContext context, SquadService service, Squad squad, SquadMember m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.s16),
            child: Text(m.displayName, style: AppText.titleM),
          ),
          ListTile(
            leading: const Icon(LucideIcons.crown, color: AppColors.squadBlue),
            title: Text('Make owner', style: AppText.bodyL),
            onTap: () async {
              Navigator.pop(sheet);
              final ok = await _confirm(context, 'Make ${m.displayName} the owner?',
                  "You'll no longer own this squad.");
              if (ok) await service.transferOwnership(squad.id, m.uid);
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.userMinus, color: AppColors.statusMissed),
            title: Text('Remove from squad',
                style: AppText.bodyL.copyWith(color: AppColors.statusMissed)),
            onTap: () async {
              Navigator.pop(sheet);
              final ok = await _confirm(context, 'Remove ${m.displayName}?',
                  "They'll be removed from this squad.");
              if (ok) await service.kickMember(squad.id, m.uid);
            },
          ),
          const SizedBox(height: Spacing.s8),
        ]),
      ),
    );
  }

  Widget _dangerZone(BuildContext context, SquadService service, Squad squad, String myUid, bool isOwner) {
    final style = OutlinedButton.styleFrom(
        foregroundColor: AppColors.statusMissed,
        side: const BorderSide(color: AppColors.statusMissed, width: 1.5),
        minimumSize: const Size.fromHeight(48));
    if (isOwner) {
      return OutlinedButton.icon(
        onPressed: () async {
          final ok = await _confirm(context, 'Delete "${squad.name}"?', 'This permanently deletes the squad for everyone.');
          if (ok) {
            await service.deleteSquad(squad.id);
            if (context.mounted) Navigator.pop(context);
          }
        },
        style: style,
        icon: const Icon(LucideIcons.trash2, size: 18),
        label: const Text('Delete squad'),
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
      style: style,
      icon: const Icon(LucideIcons.logOut, size: 18),
      label: const Text('Leave squad'),
    );
  }

  Future<void> _renameDialog(BuildContext context, SquadService service, Squad squad) async {
    final ctrl = TextEditingController(text: squad.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename squad'),
        content: TextField(controller: ctrl, maxLength: 30),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await service.renameSquad(squad.id, name);
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm',
                  style: TextStyle(color: AppColors.statusMissed))),
        ],
      ),
    );
    return res ?? false;
  }
}
