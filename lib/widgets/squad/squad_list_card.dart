import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_goal.dart';
import '../../models/squad_activity.dart';
import '../../providers/squad_provider.dart';
import '../../services/snapshot_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../ui/member_avatar.dart';
import '../ui/hero_transition_scaffold.dart';
import '../../screens/squad/squad_home_screen.dart';
import 'activity_feed_strip.dart';

/// One squad on the My Squads list: name (squadBlue underline), up to 6 member
/// avatars ordered by today's status, the latest activity line, and a TODAY
/// hit-count on the right edge. surface1, no shadow. Tap → SquadHomeScreen.
class SquadListCard extends StatelessWidget {
  final Squad squad;
  final String? uid;
  const SquadListCard({super.key, required this.squad, required this.uid});

  // Order: hit, inProgress, missed, paused, ghosted.
  static int _rank(SquadMember m, SquadDayEntry? e, DateTime now) {
    if (m.ghostedSince != null) return 4;
    if ((e?.paused ?? false) || m.pause.isCurrentlyPaused(now)) return 3;
    return switch (e?.status) {
      GoalStatus.hit => 0,
      GoalStatus.missed => 2,
      _ => 1,
    };
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final dateKey = SnapshotService.dateKey(DateTime.now());
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s12),
      child: Material(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
              context, HeroTransitionScaffold.route(SquadHomeScreen(squadId: squad.id))),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.s16),
            child: StreamBuilder<List<SquadMember>>(
              stream: service.watchMembers(squad.id),
              builder: (context, mSnap) {
                final members = mSnap.data ?? const <SquadMember>[];
                return StreamBuilder<List<SquadDayEntry>>(
                  stream: service.watchDayEntries(squad.id, dateKey),
                  builder: (context, eSnap) {
                    final entries = {
                      for (final e in (eSnap.data ?? const <SquadDayEntry>[])) e.uid: e
                    };
                    final ordered = [...members]
                      ..sort((a, b) =>
                          _rank(a, entries[a.uid], now).compareTo(_rank(b, entries[b.uid], now)));
                    final hits = entries.values
                        .where((e) => e.status == GoalStatus.hit && !e.paused)
                        .length;
                    final total = members.isNotEmpty ? members.length : squad.memberCount;
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _name(),
                          const SizedBox(height: Spacing.s12),
                          if (ordered.isNotEmpty) _avatars(ordered, entries, now),
                          const SizedBox(height: Spacing.s8),
                          _latestActivity(context, service),
                        ]),
                      ),
                      const SizedBox(width: Spacing.s12),
                      _todayHit(hits, total),
                    ]);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _name() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(squad.name, style: AppText.titleL),
        const SizedBox(height: Spacing.s4),
        Container(width: 36, height: 2, color: AppColors.squadBlue),
      ]);

  Widget _avatars(List<SquadMember> ordered, Map<String, SquadDayEntry> entries, DateTime now) {
    const max = 6;
    final shown = ordered.take(max).toList();
    final overflow = ordered.length - shown.length;
    return Row(children: [
      for (final m in shown) ...[
        MemberAvatar(
          photoURL: m.photoURL,
          displayName: m.displayName,
          lastActiveDate: m.lastActivityAt,
          paused: (entries[m.uid]?.paused ?? false) || m.pause.isCurrentlyPaused(now),
          size: 32,
        ),
        const SizedBox(width: Spacing.s4),
      ],
      if (overflow > 0)
        Container(
          width: 32, height: 32, alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
          child: Text('+$overflow',
              style: AppText.tabular(AppText.bodyS.copyWith(color: AppColors.textSecondary))),
        ),
    ]);
  }

  Widget _latestActivity(BuildContext context, service) {
    return StreamBuilder<List<SquadActivity>>(
      stream: service.watchActivity(squad.id, limit: 1),
      builder: (context, snap) {
        final a = (snap.data ?? const <SquadActivity>[]).firstOrNull;
        if (a == null) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showActivityFeedSheet(context, squad.id),
          child: Row(children: [
            Text(a.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: Spacing.s4),
            Expanded(
              child: Text(
                a.createdAt != null ? '${a.line} · ${activityAgo(a.createdAt!)}' : a.line,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppText.bodyS.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _todayHit(int hits, int total) =>
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('TODAY', style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text('$hits/$total', style: AppText.tabular(AppText.displayM)),
        Text('HIT', style: AppText.caption),
      ]);
}
