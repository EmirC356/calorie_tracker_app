import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_reaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/snapshot_provider.dart';
import '../../providers/squad_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/snapshot_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/colored_left_border_card.dart';
import '../../widgets/ui/hero_transition_scaffold.dart';
import '../../widgets/ui/shimmer_placeholder.dart';
import '../../widgets/squad/member_card.dart';
import '../../widgets/squad/checkin.dart';
import '../../widgets/squad/intention_banner.dart';
import '../../widgets/squad/group_goals_strip.dart';
import '../../widgets/squad/activity_feed.dart';
import 'member_day_detail_screen.dart';

/// Today tab: a grid of member cards (avatar, goal, progress ring, status).
class SquadTodayTab extends StatefulWidget {
  final String squadId;
  const SquadTodayTab({super.key, required this.squadId});

  @override
  State<SquadTodayTab> createState() => _SquadTodayTabState();
}

class _SquadTodayTabState extends State<SquadTodayTab> {
  late final String _dateKey;

  @override
  void initState() {
    super.initState();
    _dateKey = SnapshotService.dateKey(DateTime.now());
    // Refresh my own snapshot so my card is current when the tab opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SnapshotProvider>().pushNow();
    });
  }

  Widget _checkinBar(BuildContext context, String? mine) {
    final label = mine == null
        ? null
        : kCheckinOptions
            .firstWhere((o) => o.$1 == mine,
                orElse: () => ('', '', mine, AppColors.squadBlue))
            .$3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.s16, Spacing.s12, Spacing.s16, 0),
      child: ColoredLeftBorderCard(
        accent: mine != null ? checkinColor(mine) : AppColors.squadBlue,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s16, vertical: Spacing.s12),
        onTap: () => showCheckinSheet(context),
        child: Row(children: [
          Text(mine != null ? checkinEmoji(mine) : '👋',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: Spacing.s12),
          Expanded(
            child: Text(
              mine != null
                  ? 'Today: $label — tap to change'
                  : "How's today going? Tap to check in",
              style: AppText.bodyS,
            ),
          ),
          const Icon(LucideIcons.chevronRight,
              color: AppColors.textTertiary, size: 18),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;

    return StreamBuilder<List<SquadMember>>(
      stream: service.watchMembers(widget.squadId),
      builder: (context, mSnap) {
        if (!mSnap.hasData) {
          return ListView(
            padding: const EdgeInsets.all(Spacing.s16),
            children: const [
              ShimmerPlaceholder.card(height: 56),
              SizedBox(height: Spacing.s12),
              ShimmerPlaceholder.card(height: 280),
              SizedBox(height: Spacing.s12),
              ShimmerPlaceholder.card(height: 120),
            ],
          );
        }
        final members = mSnap.data!;
        return StreamBuilder<List<SquadDayEntry>>(
          stream: service.watchDayEntries(widget.squadId, _dateKey),
          builder: (context, eSnap) {
            final entries = {for (final e in (eSnap.data ?? const <SquadDayEntry>[])) e.uid: e};
            return StreamBuilder<List<SquadReaction>>(
              stream: service.watchReactions(widget.squadId, _dateKey),
              builder: (context, rSnap) {
                final emojiByUid = latestEmojiByRecipient(rSnap.data ?? const <SquadReaction>[]);
                return ListView(children: [
                  GroupGoalsStrip(squadId: widget.squadId),
                  if (myUid != null) IntentionBanner(squadId: widget.squadId, uid: myUid),
                  _checkinBar(context, entries[myUid]?.checkin),
                  // Horizontal snap carousel of large member cards (~85% of
                  // the screen width each), per the Squad room spec.
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: Spacing.s16),
                    child: SizedBox(
                      height: 300,
                      child: AnimationLimiter(
                        child: PageView.builder(
                          controller: PageController(viewportFraction: 0.85),
                          padEnds: false,
                          itemCount: members.length,
                          itemBuilder: (_, i) {
                            final m = members[i];
                            final entry = entries[m.uid];
                            return AnimationConfiguration.staggeredList(
                              position: i,
                              duration: AppMotion.enter,
                              delay: AppMotion.staggerStep,
                              child: SlideAnimation(
                                horizontalOffset: 48,
                                curve: Curves.easeOutCubic,
                                child: FadeInAnimation(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: Spacing.s16,
                                        right: Spacing.s4),
                                    child: MemberCard(
                                      member: m,
                                      entry: entry,
                                      isMe: m.uid == myUid,
                                      receivedEmoji: emojiByUid[m.uid],
                                      onTap: () => Navigator.push(
                                          context,
                                          HeroTransitionScaffold.route(
                                              MemberDayDetailScreen(
                                                  member: m,
                                                  entry: entry,
                                                  squadId: widget.squadId,
                                                  dateKey: _dateKey))),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  ActivityFeed(squadId: widget.squadId),
                ]);
              },
            );
          },
        );
      },
    );
  }
}
