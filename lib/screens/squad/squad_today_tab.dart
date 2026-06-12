import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_reaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/snapshot_provider.dart';
import '../../providers/squad_provider.dart';
import '../../providers/photo_provider.dart';
import '../../services/snapshot_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/hero_transition_scaffold.dart';
import '../../widgets/ui/shimmer_placeholder.dart';
import '../../widgets/squad/member_card_compact.dart';
import '../../widgets/squad/intentions_strip.dart';
import '../../widgets/squad/group_goals_strip.dart';
import '../../widgets/squad/activity_feed_strip.dart';
import 'member_day_detail_screen.dart';
import 'photo_story_viewer.dart';

/// Today tab: activity + intentions strips, a compact check-in chip, a vertical
/// stack of compact member cards (with embedded reactions), and a whole-squad
/// check-in CTA at the foot.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SnapshotProvider>().pushNow();
      context.read<PhotoProvider>().bind(widget.squadId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser?.uid;
    // A story ring shows on members with photos I haven't viewed yet (my own
    // always count — I can rewatch mine).
    final photoP = context.watch<PhotoProvider>();
    final storyUids = photoP.recentPhotos
        .where((p) => p.uploadedByUid == myUid || !photoP.isSeen(p.id))
        .map((p) => p.uploadedByUid)
        .toSet();

    return StreamBuilder<List<SquadMember>>(
      stream: service.watchMembers(widget.squadId),
      builder: (context, mSnap) {
        if (!mSnap.hasData) {
          return ListView(padding: const EdgeInsets.all(Spacing.s16), children: const [
            ShimmerPlaceholder.card(height: 48),
            SizedBox(height: Spacing.s12),
            ShimmerPlaceholder.card(height: 140),
            SizedBox(height: Spacing.s12),
            ShimmerPlaceholder.card(height: 140),
          ]);
        }
        final members = mSnap.data!;
        return StreamBuilder<List<SquadDayEntry>>(
          stream: service.watchDayEntries(widget.squadId, _dateKey),
          builder: (context, eSnap) {
            final entries = {for (final e in (eSnap.data ?? const <SquadDayEntry>[])) e.uid: e};
            return StreamBuilder<List<SquadReaction>>(
              stream: service.watchReactions(widget.squadId, _dateKey),
              builder: (context, rSnap) {
                final reactions = rSnap.data ?? const <SquadReaction>[];
                final emojiByUid = latestEmojiByRecipient(reactions);
                return ListView(
                  padding: const EdgeInsets.only(bottom: Spacing.s24),
                  children: [
                    ActivityFeedStrip(squadId: widget.squadId),
                    if (myUid != null) IntentionsStrip(squadId: widget.squadId, myUid: myUid),
                    const SizedBox(height: Spacing.s8),
                    for (final m in members)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Spacing.s16, 0, Spacing.s16, Spacing.s12),
                        child: MemberCardCompact(
                          member: m,
                          entry: entries[m.uid],
                          isMe: m.uid == myUid,
                          receivedEmoji: emojiByUid[m.uid],
                          hasStory: storyUids.contains(m.uid),
                          onAvatarTap: storyUids.contains(m.uid)
                              ? () => showPhotoStory(context, widget.squadId,
                                  uploaderUid: m.uid, name: m.displayName, photoURL: m.photoURL)
                              : null,
                          onTap: () => Navigator.push(
                              context,
                              HeroTransitionScaffold.route(MemberDayDetailScreen(
                                  member: m,
                                  entry: entries[m.uid],
                                  squadId: widget.squadId,
                                  dateKey: _dateKey))),
                        ),
                      ),
                    GroupGoalsStrip(squadId: widget.squadId),
                    _endCta(context, members, myUid),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _endCta(BuildContext context, List<SquadMember> members, String? myUid) {
    final ghosted = members.where((m) => m.ghostedSince != null && m.uid != myUid).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s8, Spacing.s16, 0),
      child: Center(
        child: TextButton.icon(
          icon: const Icon(LucideIcons.heart, size: 16, color: AppColors.squadBlue),
          label: Text('Send a check-in to the whole squad',
              style: AppText.bodyS.copyWith(color: AppColors.squadBlue)),
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context);
            if (ghosted.isEmpty || myUid == null) {
              messenger.showSnackBar(const SnackBar(content: Text('All members are active 🎉')));
              return;
            }
            final service = context.read<SquadProvider>().service;
            for (final g in ghosted) {
              service.checkInOnGhost(widget.squadId, _dateKey, g.uid, myUid);
            }
            messenger.showSnackBar(SnackBar(
                content: Text('Checked in on ${ghosted.length} quiet member'
                    '${ghosted.length == 1 ? '' : 's'} 👋')));
          },
        ),
      ),
    );
  }
}
