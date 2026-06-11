import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/squad_goal_suggestion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/squad/squad_list_card.dart';
import 'create_squad_screen.dart';
import 'join_squad_screen.dart';
import 'goal_inbox_screen.dart';

/// The Squad tab when signed in: the user's squads as rich cards + a single FAB
/// to create/join (or a centered hero when you have none).
class SquadListScreen extends StatefulWidget {
  const SquadListScreen({super.key});

  @override
  State<SquadListScreen> createState() => _SquadListScreenState();
}

class _SquadListScreenState extends State<SquadListScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.appUser;
    final squads = context.read<SquadProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => squads.bind(
          auth.firebaseUser?.uid,
          displayName: user?.displayName ?? 'Athlete',
          photoURL: user?.photoURL,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final p = context.watch<SquadProvider>();
    final uid = auth.firebaseUser?.uid;
    final hasSquads = !p.loading && p.error == null && p.squads.isNotEmpty;

    return Scaffold(
      appBar: SectionAppBar(
        title: 'My Squads',
        caption: 'Squads',
        accent: AppColors.squadBlue,
        actions: [
          if (uid != null) _InboxBadge(uid: uid),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(LucideIcons.logOut, color: AppColors.textSecondary, size: 20),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      floatingActionButton: hasSquads
          ? FloatingActionButton(
              backgroundColor: AppColors.squadBlue,
              foregroundColor: AppColors.surface0,
              onPressed: _showCreateJoinSheet,
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: _body(p, uid),
    );
  }

  Widget _body(SquadProvider p, String? uid) {
    if (p.loading) {
      return ListView(padding: const EdgeInsets.all(Spacing.s16), children: const [
        ShimmerPlaceholder.card(height: 120),
        SizedBox(height: Spacing.s12),
        ShimmerPlaceholder.card(height: 120),
      ]);
    }
    if (p.error != null) {
      return ListView(
          padding: const EdgeInsets.all(Spacing.s16), children: [_errorBox(p.error!)]);
    }
    if (p.squads.isEmpty) return _emptyHero();
    return RefreshIndicator(
      color: AppColors.squadBlue,
      onRefresh: () async => p.bind(uid),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s16, Spacing.s16, 96),
        children: [
          for (final s in p.squads) SquadListCard(squad: s, uid: uid),
          if (uid != null) _SuggestionsBanner(uid: uid),
        ],
      ),
    );
  }

  /// Centered hero for the zero-squads state (no scrolling list).
  Widget _emptyHero() => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(LucideIcons.users, color: AppColors.textTertiary, size: 72),
            const SizedBox(height: Spacing.s16),
            Text('Build your accountability squad',
                style: AppText.displayM, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.s8),
            Text('Team up with up to 10 friends and keep each other on track.',
                style: AppText.bodyL.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: Spacing.s24),
            OutlinedButton.icon(
              onPressed: _goCreate, style: _outlinedBlue(),
              icon: const Icon(LucideIcons.plus, size: 18), label: const Text('Create squad'),
            ),
            const SizedBox(height: Spacing.s12),
            OutlinedButton.icon(
              onPressed: _goJoin, style: _outlinedBlue(),
              icon: const Icon(LucideIcons.hash, size: 18), label: const Text('Join with code'),
            ),
          ]),
        ),
      );

  void _showCreateJoinSheet() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface1,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
        builder: (sheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(LucideIcons.plus, color: AppColors.squadBlue),
              title: Text('Create a squad', style: AppText.bodyL),
              onTap: () {
                Navigator.pop(sheet);
                _goCreate();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.hash, color: AppColors.squadBlue),
              title: Text('Join with a code', style: AppText.bodyL),
              onTap: () {
                Navigator.pop(sheet);
                _goJoin();
              },
            ),
            const SizedBox(height: Spacing.s8),
          ]),
        ),
      );

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(Spacing.s16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: Border.all(color: AppColors.statusMissed, width: AppMotion.focusBorderWidth),
        ),
        child: Text("Couldn't load squads: $msg",
            style: AppText.bodyM.copyWith(color: AppColors.statusMissed)),
      );

  ButtonStyle _outlinedBlue() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.squadBlue,
        side: const BorderSide(color: AppColors.squadBlue, width: AppMotion.focusBorderWidth),
        minimumSize: const Size.fromHeight(48),
      );

  void _goCreate() =>
      Navigator.push(context, HeroTransitionScaffold.route(const CreateSquadScreen()));
  void _goJoin() =>
      Navigator.push(context, HeroTransitionScaffold.route(const JoinSquadScreen()));
}

/// Below the cards: a tap-through banner when goal suggestions are waiting.
class _SuggestionsBanner extends StatelessWidget {
  final String uid;
  const _SuggestionsBanner({required this.uid});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    return StreamBuilder<List<SquadGoalSuggestion>>(
      stream: service.streamPendingSuggestionsForMe(uid),
      builder: (_, snap) {
        final n = snap.data?.length ?? 0;
        if (n == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: Spacing.s4),
          child: Material(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.r12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(LucideIcons.inbox, color: AppColors.squadBlue),
              title: Text('$n goal suggestion${n == 1 ? '' : 's'} waiting', style: AppText.bodyM),
              trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 18),
              onTap: () => Navigator.push(
                  context, HeroTransitionScaffold.route(const GoalInboxScreen())),
            ),
          ),
        );
      },
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
            icon: const Icon(LucideIcons.inbox, color: AppColors.textSecondary, size: 20),
            onPressed: () => Navigator.push(
                context, HeroTransitionScaffold.route(const GoalInboxScreen())),
          ),
          if (count > 0)
            Positioned(
              right: 6, top: 8,
              child: Container(
                padding: const EdgeInsets.all(Spacing.s4),
                decoration: const BoxDecoration(color: AppColors.statusMissed, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: AppText.tabular(
                        AppText.caption.copyWith(color: AppColors.textPrimary, fontSize: 9))),
              ),
            ),
        ]);
      },
    );
  }
}
