import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_goal.dart';
import '../../models/squad_reaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';
import 'goal_summary.dart';
import 'squad_status.dart';
import 'presence_indicator.dart';

/// Compact (~140dp) member card for the Today carousel: avatar + presence on
/// the left, name/goal/status in the middle, a small inline progress ring on
/// the right, and an embedded reaction row along the bottom. Tapping the body
/// (not the reaction pills) opens the member detail.
class MemberCardCompact extends StatelessWidget {
  final SquadMember member;
  final SquadDayEntry? entry;
  final bool isMe;
  final ReactionEmoji? receivedEmoji;
  final Map<ReactionEmoji, int> reactionCounts;
  final void Function(ReactionEmoji emoji)? onReact; // null on your own card
  final VoidCallback onTap;
  const MemberCardCompact({
    super.key,
    required this.member,
    required this.entry,
    required this.isMe,
    required this.onTap,
    this.receivedEmoji,
    this.reactionCounts = const {},
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final paused = entry?.paused ?? false;
    final status = entry?.status ?? GoalStatus.inProgress;
    final accent = entry == null ? AppColors.textTertiary : statusColor(status);
    final goal = member.effectiveGoal;
    final noGoals = !paused && goal.isEmpty;
    final progress = progressFor(goal, entry);

    return Material(
      color: AppColors.surface1,
      borderRadius: BorderRadius.circular(AppRadius.r12),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s12, Spacing.s16, Spacing.s8),
            child: Row(children: [
              _avatar(paused),
              const SizedBox(width: Spacing.s12),
              Expanded(child: _identity(goal, paused, noGoals, status)),
              const SizedBox(width: Spacing.s8),
              if (!paused && !noGoals && progress != null) _ring(progress, accent),
            ]),
          ),
        ),
        const Divider(height: 1, color: AppColors.surface2),
        _reactionRow(),
      ]),
    );
  }

  Widget _avatar(bool paused) => Stack(clipBehavior: Clip.none, children: [
        Hero(
          tag: 'squad-member-${member.uid}',
          child: MemberAvatar(
            photoURL: member.photoURL,
            displayName: member.displayName,
            lastActiveDate: member.lastActivityAt,
            paused: paused,
            size: 64,
          ),
        ),
        if (!paused)
          Positioned(
            right: -1, bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: AppColors.surface1, shape: BoxShape.circle),
              child: PresenceIndicator(lastActive: member.lastActivityAt, showLabel: false, dotSize: 9),
            ),
          ),
      ]);

  Widget _identity(SquadGoal goal, bool paused, bool noGoals, GoalStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(children: [
          Flexible(
            child: Text(isMe ? '${member.displayName} (you)' : member.displayName,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleL),
          ),
          if (receivedEmoji != null) ...[
            const SizedBox(width: Spacing.s4),
            Text(receivedEmoji!.glyph, style: const TextStyle(fontSize: 14)),
          ],
        ]),
        const SizedBox(height: Spacing.s4),
        if (noGoals)
          Text('No goals shared', style: AppText.caption.copyWith(color: AppColors.textTertiary))
        else ...[
          GoalSummary(goal: goal, fontSize: 13),
          const SizedBox(height: Spacing.s4),
          Align(
            alignment: Alignment.centerLeft,
            child: paused
                ? StatusPill(
                    status: PillStatus.paused,
                    label: member.pause.until != null
                        ? 'Paused til ${_shortDate(member.pause.until!)}'
                        : 'Paused')
                : StatusPill(
                    status: pillStatusFor(status), label: entry == null ? 'No data' : null),
          ),
        ],
      ],
    );
  }

  // Inline 48dp ring with the percentage in its centre. The amber in-progress
  // colour carries the "in progress" state — no extra clock icon or pill.
  Widget _ring(double progress, Color accent) => AnimatedRing(
        progress: progress,
        accent: accent,
        size: 48,
        child: Text('${(progress * 100).round()}%',
            style: AppText.tabular(AppText.bodyS.copyWith(color: accent))),
      );

  Widget _reactionRow() {
    final disabled = onReact == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s8),
      child: Row(children: [
        for (final e in ReactionEmoji.values) ...[
          _pill(e, reactionCounts[e] ?? 0, disabled),
          const SizedBox(width: Spacing.s8),
        ],
      ]),
    );
  }

  Widget _pill(ReactionEmoji e, int count, bool disabled) => Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onReact!(e);
                },
          child: Opacity(
            opacity: disabled ? 0.35 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(e.glyph, style: const TextStyle(fontSize: 15)),
                if (count > 0) ...[
                  const SizedBox(width: Spacing.s4),
                  Text('$count',
                      style: AppText.tabular(AppText.caption.copyWith(color: AppColors.textSecondary))),
                ],
              ]),
            ),
          ),
        ),
      );

  static String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}
