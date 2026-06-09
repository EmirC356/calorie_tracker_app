import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_reaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/squad/goal_summary.dart';
import '../../widgets/squad/squad_status.dart';
import '../../widgets/squad/reaction_bar.dart';

/// Shows a member's day at whatever detail their sharing level allows, plus a
/// reaction bar (🔥 💪 👏).
class MemberDayDetailScreen extends StatelessWidget {
  final SquadMember member;
  final SquadDayEntry? entry;
  final String squadId;
  final String dateKey;
  const MemberDayDetailScreen({
    super.key,
    required this.member,
    required this.entry,
    required this.squadId,
    required this.dateKey,
  });

  @override
  Widget build(BuildContext context) {
    final status = entry?.status;
    final color = status == null ? kTextDim : statusColor(status);
    return Scaffold(
      appBar: AppBar(
        title: Text(member.displayName.toUpperCase()),
        titleTextStyle: const TextStyle(color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        iconTheme: const IconThemeData(color: kNavy),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          CircleAvatar(
            radius: 26, backgroundColor: kCard,
            backgroundImage: (member.photoURL?.isNotEmpty ?? false) ? NetworkImage(member.photoURL!) : null,
            child: (member.photoURL?.isEmpty ?? true) ? const Icon(Icons.person, color: kNavy) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.displayName, style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            GoalSummary(goal: member.goal),
          ])),
        ]),
        const SizedBox(height: 16),
        if (status != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon(status), color: color, size: 18),
              const SizedBox(width: 8),
              Text(statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ]),
          ),
        const SizedBox(height: 16),
        if (entry == null)
          const Text('No data logged yet today.', style: TextStyle(color: kTextDim))
        else if (entry!.hasTotals) ...[
          _totals(entry!),
          if (entry!.hasDetails) ...[
            const SizedBox(height: 16),
            _details(entry!),
          ],
        ] else
          const Text('This member shares only their status with the squad.',
              style: TextStyle(color: kTextDim)),
        const SizedBox(height: 20),
        _reactions(context),
      ]),
    );
  }

  Widget _reactions(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser?.uid;
    final myName = auth.appUser?.displayName ?? 'Athlete';
    if (myUid == null) return const SizedBox.shrink();
    return StreamBuilder<List<SquadReaction>>(
      stream: service.watchReactions(squadId, dateKey),
      builder: (context, snap) {
        final forMember =
            (snap.data ?? const <SquadReaction>[]).where((r) => r.toUid == member.uid).toList();
        return ReactionBar(
          reactions: forMember,
          myUid: myUid,
          onTap: (emoji) {
            final mine = forMember.where((r) => r.fromUid == myUid && r.emoji == emoji).toList();
            if (mine.isNotEmpty) {
              service.removeReaction(squadId: squadId, dateKey: dateKey, reactionId: mine.first.id);
            } else {
              service.addReaction(
                  squadId: squadId, dateKey: dateKey, fromUid: myUid, fromName: myName,
                  toUid: member.uid, emoji: emoji);
            }
          },
        );
      },
    );
  }

  Widget _totals(SquadDayEntry e) => Container(
        padding: const EdgeInsets.all(14),
        decoration: neonBox(kNavy),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('CONSUMED', e.consumed?.toStringAsFixed(0) ?? '–', 'kcal'),
          _stat('BURNED', e.burned?.toStringAsFixed(0) ?? '–', 'kcal'),
          _stat('EXERCISE', '${e.exerciseMinutes ?? '–'}', 'min'),
        ]),
      );

  Widget _stat(String label, String value, String unit) => Column(children: [
        Text(label, style: const TextStyle(color: kTextDim, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(color: kTextDim, fontSize: 10)),
      ]);

  Widget _details(SquadDayEntry e) {
    String fmt(DateTime? t) => t == null ? '' : DateFormat('HH:mm').format(t);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ((e.meals ?? []).isNotEmpty) ...[
        Text('MEALS', style: neonLabel(kNavy, size: 12)),
        const SizedBox(height: 8),
        ...e.meals!.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: Text(m.name, style: const TextStyle(color: kText, fontSize: 13))),
                Text('${m.kcal.toStringAsFixed(0)} kcal  ${fmt(m.time)}',
                    style: const TextStyle(color: kTextDim, fontSize: 12)),
              ]),
            )),
        const SizedBox(height: 12),
      ],
      if ((e.exercises ?? []).isNotEmpty) ...[
        Text('EXERCISES', style: neonLabel(kNavy, size: 12)),
        const SizedBox(height: 8),
        ...e.exercises!.map((x) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: Text(x.name, style: const TextStyle(color: kText, fontSize: 13))),
                Text('${x.minutes} min · ${x.kcal.toStringAsFixed(0)} kcal  ${fmt(x.time)}',
                    style: const TextStyle(color: kTextDim, fontSize: 12)),
              ]),
            )),
      ],
    ]);
  }
}
