import 'package:flutter/material.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_goal.dart';
import '../../theme/app_theme.dart';
import 'goal_summary.dart';
import 'progress_ring.dart';
import 'squad_status.dart';

/// A member's Today card: avatar, name, goal, progress ring, status badge.
class MemberCard extends StatelessWidget {
  final SquadMember member;
  final SquadDayEntry? entry;
  final bool isMe;
  final VoidCallback onTap;
  const MemberCard({super.key, required this.member, required this.entry, required this.isMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = entry?.status ?? GoalStatus.inProgress;
    final color = entry == null ? kBorderDim : statusColor(status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: neonBox(color),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            CircleAvatar(
              radius: 16, backgroundColor: kSurface,
              backgroundImage: (member.photoURL?.isNotEmpty ?? false) ? NetworkImage(member.photoURL!) : null,
              child: (member.photoURL?.isEmpty ?? true) ? const Icon(Icons.person, color: kNavy, size: 16) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(isMe ? '${member.displayName} (you)' : member.displayName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          ProgressRing(
            value: progressFor(member.goal, entry),
            color: color,
            size: 54,
            center: Icon(statusIcon(status), color: color, size: 20),
          ),
          const SizedBox(height: 8),
          GoalSummary(goal: member.goal, fontSize: 10, color: kNavy),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Text(entry == null ? 'NO DATA' : statusLabel(status),
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}
