import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_goal.dart';
import '../../models/squad_goal_suggestion.dart';
import '../../models/squad_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/snapshot_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';
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
      appBar: SectionAppBar(
        title: 'My Squads',
        caption: 'Squads',
        accent: AppColors.squadBlue,
        actions: [
          if (auth.firebaseUser?.uid != null)
            _InboxBadge(uid: auth.firebaseUser!.uid),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(LucideIcons.logOut,
                color: AppColors.textSecondary, size: 20),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.squadBlue,
        onRefresh: () async => squadProvider.bind(auth.firebaseUser?.uid),
        child: ListView(
          padding: const EdgeInsets.all(Spacing.s16),
          children: [
            // Identity row — who I appear as to my squads.
            Row(children: [
              MemberAvatar(
                photoURL:
                    (user?.photoURL?.isNotEmpty ?? false) ? user!.photoURL : null,
                displayName: user?.displayName ?? 'Athlete',
                size: 44,
              ),
              const SizedBox(width: Spacing.s12),
              Expanded(
                child: Text(user?.displayName ?? 'Athlete',
                    style: AppText.titleM),
              ),
            ]),
            const SizedBox(height: Spacing.s16),

            if (squadProvider.loading) ...[
              const ShimmerPlaceholder.card(height: 120),
              const SizedBox(height: Spacing.s12),
              const ShimmerPlaceholder.card(height: 120),
            ] else if (squadProvider.error != null)
              _errorBox(squadProvider.error!)
            else if (squadProvider.squads.isEmpty)
              _emptyState()
            else
              ...squadProvider.squads
                  .map((s) => _SquadCard(squad: s, uid: auth.firebaseUser?.uid)),

            if (!squadProvider.loading && squadProvider.squads.isNotEmpty) ...[
              const SizedBox(height: Spacing.s8),
              _actions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Column(children: [
        const SizedBox(height: Spacing.s32),
        const Icon(LucideIcons.userPlus,
            color: AppColors.textTertiary, size: 64),
        const SizedBox(height: Spacing.s16),
        Text('Build your accountability squad',
            style: AppText.displayM, textAlign: TextAlign.center),
        const SizedBox(height: Spacing.s8),
        Text('Create a squad or join one with a 6-digit code.',
            style: AppText.bodyL.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: Spacing.s24),
        OutlinedButton.icon(
          onPressed: _goCreate,
          style: _outlinedBlue(),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Create squad'),
        ),
        const SizedBox(height: Spacing.s12),
        OutlinedButton.icon(
          onPressed: _goJoin,
          style: _outlinedBlue(),
          icon: const Icon(LucideIcons.hash, size: 18),
          label: const Text('Join with code'),
        ),
      ]);

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(Spacing.s16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: Border.all(
              color: AppColors.statusMissed,
              width: AppMotion.focusBorderWidth),
        ),
        child: Text('Couldn\'t load squads: $msg',
            style: AppText.bodyM.copyWith(color: AppColors.statusMissed)),
      );

  ButtonStyle _outlinedBlue() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.squadBlue,
        side: const BorderSide(
            color: AppColors.squadBlue, width: AppMotion.focusBorderWidth),
        minimumSize: const Size.fromHeight(48),
      );

  void _goCreate() => Navigator.push(
      context, HeroTransitionScaffold.route(const CreateSquadScreen()));

  void _goJoin() => Navigator.push(
      context, HeroTransitionScaffold.route(const JoinSquadScreen()));

  Widget _actions() => Column(children: [
        ElevatedButton.icon(
          onPressed: _goCreate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.squadBlue,
            foregroundColor: AppColors.surface0,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Create squad'),
        ),
        const SizedBox(height: Spacing.s12),
        OutlinedButton.icon(
          onPressed: _goJoin,
          style: _outlinedBlue(),
          icon: const Icon(LucideIcons.hash, size: 18),
          label: const Text('Join with code'),
        ),
      ]);
}

/// One squad as a ColoredLeftBorderCard: member avatars on top, name in
/// titleL, "x / y hit today" + membership meta in caption. Live member/entry
/// streams (read-only — same service streams the Today tab consumes).
class _SquadCard extends StatelessWidget {
  final Squad squad;
  final String? uid;
  const _SquadCard({required this.squad, required this.uid});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final isOwner = uid != null && squad.isOwner(uid!);
    final dateKey = SnapshotService.dateKey(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s12),
      child: ColoredLeftBorderCard(
        accent: AppColors.squadBlue,
        onTap: () => Navigator.push(context,
            HeroTransitionScaffold.route(SquadHomeScreen(squadId: squad.id))),
        child: StreamBuilder<List<SquadMember>>(
          stream: service.watchMembers(squad.id),
          builder: (context, mSnap) {
            final members = mSnap.data ?? const <SquadMember>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (members.isNotEmpty) ...[
                  Row(children: [
                    for (final m in members.take(8)) ...[
                      MemberAvatar(
                        photoURL: m.photoURL,
                        displayName: m.displayName,
                        size: 28,
                      ),
                      const SizedBox(width: Spacing.s4),
                    ],
                  ]),
                  const SizedBox(height: Spacing.s12),
                ],
                Text(squad.name, style: AppText.titleL),
                const SizedBox(height: Spacing.s4),
                StreamBuilder<List<SquadDayEntry>>(
                  stream: service.watchDayEntries(squad.id, dateKey),
                  builder: (context, eSnap) {
                    final hits = (eSnap.data ?? const <SquadDayEntry>[])
                        .where((e) => e.status == GoalStatus.hit)
                        .length;
                    final total =
                        members.isNotEmpty ? members.length : squad.memberCount;
                    return Text(
                      '$hits / $total HIT TODAY'
                      '  ·  ${squad.memberCount}/${Squad.maxMembers} MEMBERS'
                      '${isOwner ? '  ·  OWNER' : ''}',
                      style: AppText.tabular(AppText.caption),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
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
            icon: const Icon(LucideIcons.inbox,
                color: AppColors.textSecondary, size: 20),
            onPressed: () => Navigator.push(
                context, HeroTransitionScaffold.route(const GoalInboxScreen())),
          ),
          if (count > 0)
            Positioned(
              right: 6,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(Spacing.s4),
                decoration: const BoxDecoration(
                    color: AppColors.statusMissed, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: AppText.tabular(AppText.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 9,
                    ))),
              ),
            ),
        ]);
      },
    );
  }
}
