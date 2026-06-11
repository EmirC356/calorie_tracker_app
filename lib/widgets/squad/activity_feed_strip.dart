import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/activity_feed_provider.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../ui/member_avatar.dart';

/// Accent color for an event type (status colors + section accent).
Color activityAccent(SquadActivity a) => switch (a.normalizedType) {
      'goalHit' || 'pauseEnded' || 'fullSquadDay' => AppColors.statusHit,
      'streakBroken' => AppColors.statusMissed,
      'streakMilestone' || 'birthday' => AppColors.calendarAmber,
      'pauseStarted' => AppColors.statusPaused,
      'memberLeft' => AppColors.textTertiary,
      _ => AppColors.squadBlue,
    };

String activityAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

const _typeLabels = {
  'goalHit': 'Goals',
  'streakMilestone': 'Streaks',
  'streakBroken': 'Streaks',
  'commentPosted': 'Comments',
  'reactionSent': 'Nudges',
  'pauseStarted': 'Pauses',
  'pauseEnded': 'Pauses',
  'memberJoined': 'Members',
  'memberLeft': 'Members',
  'intentionSet': 'Intentions',
  'fullSquadDay': 'Squad',
  'groupGoalHit': 'Squad',
  'birthday': 'Birthdays',
};

/// Compact one-line activity strip for the Today tab. Auto-cycles every 6s when
/// there are multiple events; tap opens the full feed sheet.
class ActivityFeedStrip extends StatefulWidget {
  final String squadId;
  const ActivityFeedStrip({super.key, required this.squadId});

  @override
  State<ActivityFeedStrip> createState() => _ActivityFeedStripState();
}

class _ActivityFeedStripState extends State<ActivityFeedStrip> {
  Timer? _cycle;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ActivityFeedProvider>().bind(widget.squadId);
    });
    _cycle = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final n = context.read<ActivityFeedProvider>().events.length;
      if (n > 1) setState(() => _i = (_i + 1) % n);
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = context.watch<ActivityFeedProvider>().events;
    if (events.isEmpty) return const SizedBox.shrink();
    final a = events[_i % events.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s8, Spacing.s16, 0),
      child: Material(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showActivityFeedSheet(context, widget.squadId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s8),
            child: Row(children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: activityAccent(a))),
              const SizedBox(width: Spacing.s8),
              Text(a.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: Spacing.s8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(a.line,
                      key: ValueKey(a.id),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyM),
                ),
              ),
              if (a.createdAt != null) ...[
                const SizedBox(width: Spacing.s8),
                Text(activityAgo(a.createdAt!),
                    style: AppText.caption.copyWith(color: AppColors.textTertiary)),
              ],
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
            ]),
          ),
        ),
      ),
    );
  }
}

Future<void> showActivityFeedSheet(BuildContext context, String squadId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface0,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
      builder: (_) => _ActivityFeedSheet(squadId: squadId),
    );

class _ActivityFeedSheet extends StatefulWidget {
  final String squadId;
  const _ActivityFeedSheet({required this.squadId});

  @override
  State<_ActivityFeedSheet> createState() => _ActivityFeedSheetState();
}

class _ActivityFeedSheetState extends State<_ActivityFeedSheet> {
  String? _filter; // normalized type, or null = All

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return StreamBuilder<List<SquadActivity>>(
          stream: service.watchActivity(widget.squadId, limit: 100),
          builder: (context, snap) {
            final all = snap.data ?? const <SquadActivity>[];
            final present = <String>{for (final a in all) a.normalizedType}.toList();
            final shown = _filter == null
                ? all
                : all.where((a) => a.normalizedType == _filter).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: Spacing.s8),
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.surface2, borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s12, Spacing.s16, Spacing.s8),
                child: Text('SQUAD ACTIVITY', style: AppText.caption),
              ),
              if (present.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
                    children: [
                      _filterChip('All', _filter == null, () => setState(() => _filter = null)),
                      for (final t in _orderedTypes(present))
                        _filterChip(_typeLabels[t] ?? t, _filter == t,
                            () => setState(() => _filter = t)),
                    ],
                  ),
                ),
              const SizedBox(height: Spacing.s8),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.squadBlue,
                  onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 300)),
                  child: shown.isEmpty
                      ? ListView(
                          controller: controller,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(Spacing.s24),
                              child: Center(
                                  child: Text('No activity yet.',
                                      style: AppText.bodyM
                                          .copyWith(color: AppColors.textTertiary))),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(Spacing.s16, 0, Spacing.s16, Spacing.s24),
                          itemCount: shown.length,
                          itemBuilder: (_, i) => _row(shown[i]),
                        ),
                ),
              ),
            ]);
          },
        );
      },
    );
  }

  // Distinct labels, keeping first occurrence order.
  List<String> _orderedTypes(List<String> present) {
    final seenLabels = <String>{};
    final out = <String>[];
    for (final t in present) {
      final label = _typeLabels[t] ?? t;
      if (seenLabels.add(label)) out.add(t);
    }
    return out;
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: Spacing.s8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                  color: active ? AppColors.squadBlue : AppColors.surface2,
                  width: active ? 1.5 : 1),
            ),
            child: Text(label,
                style: AppText.bodyS.copyWith(
                    color: active ? AppColors.squadBlue : AppColors.textSecondary)),
          ),
        ),
      );

  Widget _row(SquadActivity a) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (a.actorName.trim().isNotEmpty)
            MemberAvatar(photoURL: a.actorPhotoURL, displayName: a.actorName, size: 32)
          else
            Text(a.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: Spacing.s12),
          Expanded(child: Text(a.line, style: AppText.bodyM)),
          const SizedBox(width: Spacing.s8),
          Container(
              width: 6, height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: activityAccent(a))),
          if (a.createdAt != null) ...[
            const SizedBox(width: Spacing.s8),
            Text(activityAgo(a.createdAt!),
                style: AppText.caption.copyWith(color: AppColors.textTertiary)),
          ],
        ]),
      );
}
