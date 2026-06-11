import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_reaction.dart';
import '../../models/squad_goal.dart';
import '../../models/goal_visible.dart';
import '../../models/date_helpers.dart';
import '../../providers/auth_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/member_avatar.dart';
import '../../widgets/ui/status_pill.dart';
import '../../widgets/squad/goal_summary.dart';
import '../../widgets/squad/goal_row.dart';
import '../../widgets/squad/squad_status.dart';
import '../../widgets/squad/reaction_bar.dart';
import '../../widgets/squad/squadmate_goals.dart';
import '../../widgets/squad/comment_thread.dart';
import 'goal_suggest_screen.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(member.displayName)),
      body: ListView(padding: const EdgeInsets.all(Spacing.s16), children: [
        Row(children: [
          Hero(
            tag: 'squad-member-${member.uid}',
            child: MemberAvatar(
              photoURL: (member.photoURL?.isNotEmpty ?? false)
                  ? member.photoURL
                  : null,
              displayName: member.displayName,
              paused: entry?.paused ?? false,
              size: 56,
            ),
          ),
          const SizedBox(width: Spacing.s12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.displayName, style: AppText.titleL),
            const SizedBox(height: Spacing.s4),
            GoalSummary(goal: member.effectiveGoal),
          ])),
        ]),
        const SizedBox(height: Spacing.s16),
        if (status != null)
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(status: pillStatusFor(status)),
          ),
        const SizedBox(height: Spacing.s16),
        if (entry == null)
          Text('No data logged yet today.',
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary))
        else if (entry!.hasTotals) ...[
          _totals(entry!),
          if (entry!.hasDetails) ...[
            const SizedBox(height: Spacing.s16),
            _details(entry!),
          ],
        ] else
          Text('This member shares only their status with the squad.',
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: Spacing.s24),
        _goalsSection(context),
        const SizedBox(height: 20),
        _reactions(context),
        _suggestButton(context),
        const SizedBox(height: 24),
        _commentThread(context),
      ]),
    );
  }

  /// Today's squad-visible goals + the weekly goal-stats card, streamed live.
  Widget _goalsSection(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;
    if (myUid == null) return const SizedBox.shrink();
    return StreamBuilder<List<GoalVisible>>(
      stream: service.streamSquadmateGoalsVisible(member.uid, myUid),
      builder: (_, snap) {
        final goals = snap.data ?? const <GoalVisible>[];
        if (goals.isEmpty && snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final today = ymd(dateOnly(DateTime.now()));
        // Calendar goal occurrences shared for today.
        final todays = goals.where((g) => g.date == today).toList();
        final primary = _primaryGoalTitles();
        final dayPill = _dayPillStatus();
        final hasAny = primary.isNotEmpty || todays.isNotEmpty;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!hasAny)
            Text('No goals shared today',
                style: AppText.bodyM.copyWith(color: AppColors.textTertiary))
          else ...[
            Text("TODAY'S GOALS", style: AppText.caption),
            const SizedBox(height: Spacing.s8),
            // Primary effective goal(s) first — the profile/override goal.
            for (final t in primary) GoalRow(title: t, status: dayPill),
            // Then squad-visible Calendar goal occurrences.
            for (final g in todays)
              GoalRow(
                title: g.goalTitle,
                subtitle: g.metricSummary,
                dotColor: Color(g.colorArgb),
                status: _calendarPill(g.status),
              ),
          ],
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 16),
            SquadmateGoalStats(goals: goals),
          ],
        ]);
      },
    );
  }

  /// Rich titles for the member's primary effective goal (profile snapshot when
  /// inherited, else the explicit squad goal).
  List<String> _primaryGoalTitles() {
    final out = <String>[];
    if (member.inheritedFromProfile && !member.profileGoalSnapshot.isEmpty) {
      final s = member.profileGoalSnapshot;
      if (s.calorieSummary != null) out.add(s.calorieSummary!);
      if (s.exerciseSummary != null) out.add(s.exerciseSummary!);
    } else {
      final g = member.goal;
      if (g.calorieActive) {
        out.add('${g.calorieMode == CalorieMode.cap ? '≤' : '≥'} ${g.calorieTarget} kcal/day');
      }
      if (g.exerciseMinutesMin != null) out.add('≥ ${g.exerciseMinutesMin} min exercise/day');
      if (g.caloriesBurnedMin != null) out.add('≥ ${g.caloriesBurnedMin} kcal burned/day');
    }
    return out;
  }

  PillStatus? _dayPillStatus() {
    if (entry == null) return null;
    if (entry!.paused) return PillStatus.paused;
    return pillStatusFor(entry!.status);
  }

  PillStatus _calendarPill(String occurrenceStatus) => switch (occurrenceStatus) {
        'done' => PillStatus.hit,
        'missed' => PillStatus.missed,
        _ => PillStatus.inProgress,
      };

  /// "Suggest a goal" entry point (squadmates only — not yourself).
  Widget _suggestButton(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser?.uid;
    final myName = auth.appUser?.displayName ?? 'Athlete';
    if (myUid == null || member.uid == myUid) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        onPressed: () async {
          final sent = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => GoalSuggestScreen(
                squadId: squadId,
                fromUid: myUid,
                fromName: myName,
                toUid: member.uid,
                toName: member.displayName,
              ),
            ),
          );
          if (sent == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Goal suggested to ${member.displayName}')));
          }
        },
        icon: const Icon(LucideIcons.lightbulb, size: 18),
        label: Text('Suggest a goal to ${member.displayName}'),
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.squadBlue,
            side: const BorderSide(color: AppColors.squadBlue, width: 1.5),
            minimumSize: const Size.fromHeight(46)),
      ),
    );
  }

  Widget _commentThread(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser?.uid;
    if (myUid == null) return const SizedBox.shrink();
    return CommentThread(
      squadId: squadId,
      dateKey: dateKey,
      toUid: member.uid,
      myUid: myUid,
      myName: auth.appUser?.displayName ?? 'Athlete',
    );
  }

  Widget _reactions(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser?.uid;
    final myName = auth.appUser?.displayName ?? 'Athlete';
    if (myUid == null) return const SizedBox.shrink();

    // Can't nudge yourself.
    if (member.uid == myUid) {
      return Text("This is you — open a squadmate's card to send a nudge.",
          style: AppText.bodyS.copyWith(color: AppColors.textTertiary));
    }

    final squadProvider = context.read<SquadProvider>();
    return ReactionBar(
      onSend: (emoji) {
        final remaining = squadProvider.nudgeCooldownRemaining(squadId, member.uid);
        if (remaining > Duration.zero) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('You can nudge ${member.displayName} again in ${remaining.inSeconds}s')));
          return;
        }
        squadProvider.markNudged(squadId, member.uid);
        service.addReaction(
            squadId: squadId, dateKey: dateKey, fromUid: myUid, fromName: myName,
            toUid: member.uid, emoji: emoji);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${emoji.glyph} sent to ${member.displayName}')));
      },
    );
  }

  /// Day stats stacked as hero numbers (tabular displayM), per the spec's
  /// "stats as HeroStats stacked" treatment.
  Widget _totals(SquadDayEntry e) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _stat('CONSUMED', e.consumed?.toStringAsFixed(0) ?? '–', 'kcal'),
        _stat('BURNED', e.burned?.toStringAsFixed(0) ?? '–', 'kcal'),
        _stat('EXERCISE', '${e.exerciseMinutes ?? '–'}', 'min'),
      ]);

  Widget _stat(String label, String value, String unit) => Column(children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text(value, style: AppText.tabular(AppText.displayM)),
        Text(unit, style: AppText.caption),
      ]);

  Widget _details(SquadDayEntry e) {
    String fmt(DateTime? t) => t == null ? '' : DateFormat('HH:mm').format(t);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ((e.meals ?? []).isNotEmpty) ...[
        Text('MEALS', style: AppText.caption),
        const SizedBox(height: Spacing.s8),
        ...e.meals!.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.s8),
              child: Row(children: [
                Expanded(child: Text(m.name, style: AppText.bodyS)),
                Text('${m.kcal.toStringAsFixed(0)} kcal  ${fmt(m.time)}',
                    style: AppText.tabular(AppText.bodyS
                        .copyWith(color: AppColors.textSecondary))),
              ]),
            )),
        const SizedBox(height: Spacing.s12),
      ],
      if ((e.exercises ?? []).isNotEmpty) ...[
        Text('EXERCISES', style: AppText.caption),
        const SizedBox(height: Spacing.s8),
        ...e.exercises!.map((x) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.s8),
              child: Row(children: [
                Expanded(child: Text(x.name, style: AppText.bodyS)),
                Text('${x.minutes} min · ${x.kcal.toStringAsFixed(0)} kcal  ${fmt(x.time)}',
                    style: AppText.tabular(AppText.bodyS
                        .copyWith(color: AppColors.textSecondary))),
              ]),
            )),
      ],
    ]);
  }
}
