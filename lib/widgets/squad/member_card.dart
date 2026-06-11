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
import 'checkin.dart';

/// A member's Today card, sized for the horizontal snap carousel (~85% of the
/// screen width): MemberAvatar, name in titleL, goal summary, AnimatedRing in
/// the status color, StatusPill below. Depth comes from the surface ladder —
/// no borders, no glows (design/system.md).
class MemberCard extends StatelessWidget {
  final SquadMember member;
  final SquadDayEntry? entry;
  final bool isMe;
  final ReactionEmoji? receivedEmoji;
  final VoidCallback onTap;
  const MemberCard({
    super.key,
    required this.member,
    required this.entry,
    required this.isMe,
    required this.onTap,
    this.receivedEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final paused = entry?.paused ?? false;
    final status = entry?.status ?? GoalStatus.inProgress;
    final accent = entry == null ? AppColors.textTertiary : statusColor(status);

    return Material(
      color: AppColors.surface1,
      borderRadius: BorderRadius.circular(AppRadius.r12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _identityRow(),
              if (paused)
                const Text('🌴', style: TextStyle(fontSize: 48))
              else
                AnimatedRing(
                  progress: progressFor(member.goal, entry) ?? 0,
                  accent: accent,
                  size: 116,
                  child: Icon(statusIcon(status), color: accent, size: 28),
                ),
              if (paused)
                StatusPill(
                  status: PillStatus.paused,
                  label: member.pause.until != null
                      ? 'Paused til ${_shortDate(member.pause.until!)}'
                      : 'Paused',
                )
              else
                StatusPill(
                  status: pillStatusFor(status),
                  // No entry yet today — keep the "no data" signal visible.
                  label: entry == null ? 'No data' : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityRow() {
    return Row(children: [
      Hero(
        tag: 'squad-member-${member.uid}',
        child: MemberAvatar(
          photoURL: member.photoURL,
          displayName: member.displayName,
          paused: entry?.paused ?? false,
          size: 56,
        ),
      ),
      const SizedBox(width: Spacing.s12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isMe ? '${member.displayName} (you)' : member.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.titleL,
          ),
          const SizedBox(height: Spacing.s4),
          GoalSummary(goal: member.goal, fontSize: 14),
        ]),
      ),
      if (entry?.checkin != null) ...[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: checkinColor(entry!.checkin)),
        ),
        const SizedBox(width: Spacing.s4),
      ],
      if (receivedEmoji != null)
        Text(receivedEmoji!.glyph, style: const TextStyle(fontSize: 18)),
    ]);
  }

  static String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}
