import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_reaction.dart';
import '../../models/squad_goal.dart';
import '../../models/goal_visible.dart';
import '../../models/date_helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/member_avatar.dart';
import '../../widgets/ui/status_pill.dart';
import '../../widgets/squad/goal_row.dart';
import '../../widgets/squad/squad_status.dart';
import '../../widgets/squad/squadmate_goals.dart';
import '../../widgets/squad/comment_thread.dart';
import '../../widgets/squad/presence_indicator.dart';
import 'goal_suggest_screen.dart';

/// A member's day, reordered around the social actions: a hero identity block,
/// then a primary reaction bar, today's goals, collapsed day stats, the meal /
/// exercise timelines (per sharing level), weekly stats, and comments.
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
    final showCalories = member.effectiveGoal.calorieActive;
    final hasTotals = entry?.hasTotals ?? false;
    final hasDetails = entry?.hasDetails ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(member.displayName)),
      body: ListView(padding: const EdgeInsets.all(Spacing.s16), children: [
        _hero(),
        const SizedBox(height: Spacing.s20),
        _reactions(context),
        const SizedBox(height: Spacing.s24),
        _todaysGoals(context),
        _suggestButton(context),
        if (entry == null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.s24),
            child: Text('No data logged yet today.',
                style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
          )
        else if (!hasTotals)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.s24),
            child: Text('This member shares only their status with the squad.',
                style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
          )
        else ...[
          const SizedBox(height: Spacing.s24),
          _statRow(entry!, showCalories),
          if (hasDetails) ...[
            if (showCalories) _meals(entry!),
            _exercises(entry!),
          ],
        ],
        _weeklyStats(context),
        const SizedBox(height: Spacing.s24),
        _commentThread(context),
      ]),
    );
  }

  // ── 1. Hero identity block ────────────────────────────────────────────────
  Widget _hero() {
    final pill = _dayPillStatus();
    return Column(children: [
      Hero(
        tag: 'squad-member-${member.uid}',
        child: MemberAvatar(
          photoURL: (member.photoURL?.isNotEmpty ?? false) ? member.photoURL : null,
          displayName: member.displayName,
          lastActiveDate: member.lastActivityAt,
          paused: entry?.paused ?? false,
          size: 96,
        ),
      ),
      const SizedBox(height: Spacing.s12),
      Text(member.displayName, style: AppText.displayM, textAlign: TextAlign.center),
      const SizedBox(height: Spacing.s4),
      PresenceIndicator(lastActive: member.lastActivityAt),
      if (pill != null) ...[
        const SizedBox(height: Spacing.s12),
        StatusPill(status: pill),
      ],
    ]);
  }

  // ── 2. Primary reaction bar (full-width) ──────────────────────────────────
  Widget _reactions(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser?.uid;
    final myName = auth.appUser?.displayName ?? 'Athlete';
    if (myUid == null) return const SizedBox.shrink();
    if (member.uid == myUid) {
      return Text("This is you — open a squadmate's card to send a nudge.",
          textAlign: TextAlign.center,
          style: AppText.bodyS.copyWith(color: AppColors.textTertiary));
    }
    final sp = context.read<SquadProvider>();
    void send(ReactionEmoji e) {
      final remaining = sp.nudgeCooldownRemaining(squadId, member.uid);
      final messenger = ScaffoldMessenger.of(context);
      if (remaining > Duration.zero) {
        messenger.showSnackBar(SnackBar(
            content: Text('Nudge ${member.displayName} again in ${remaining.inSeconds}s')));
        return;
      }
      HapticFeedback.lightImpact();
      sp.markNudged(squadId, member.uid);
      service.addReaction(
          squadId: squadId, dateKey: dateKey, fromUid: myUid, fromName: myName,
          toUid: member.uid, emoji: e);
      messenger.showSnackBar(
          SnackBar(content: Text('${e.glyph} sent to ${member.displayName}')));
    }

    return Row(children: [
      for (final e in ReactionEmoji.values) ...[
        Expanded(
          child: Material(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.r12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => send(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.s12),
                child: Center(child: Text(e.glyph, style: const TextStyle(fontSize: 24))),
              ),
            ),
          ),
        ),
        if (e != ReactionEmoji.values.last) const SizedBox(width: Spacing.s12),
      ],
    ]);
  }

  // ── 3. Today's goals ──────────────────────────────────────────────────────
  Widget _todaysGoals(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;
    if (myUid == null) return const SizedBox.shrink();
    return StreamBuilder<List<GoalVisible>>(
      stream: service.streamSquadmateGoalsVisible(member.uid, myUid),
      builder: (_, snap) {
        final goals = snap.data ?? const <GoalVisible>[];
        final today = ymd(dateOnly(DateTime.now()));
        final todays = goals.where((g) => g.date == today).toList();
        final primary = _primaryGoalTitles();
        final dayPill = _dayPillStatus();
        if (primary.isEmpty && todays.isEmpty) {
          return Text('No goals shared today',
              style: AppText.bodyM.copyWith(color: AppColors.textTertiary));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("TODAY'S GOALS", style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          for (final t in primary) GoalRow(title: t, status: dayPill),
          for (final g in todays)
            GoalRow(
              title: g.goalTitle,
              subtitle: g.metricSummary,
              dotColor: Color(g.colorArgb),
              status: _calendarPill(g.status),
            ),
        ]);
      },
    );
  }

  // ── 4. Collapsed 2-stat row (CONSUMED + EXERCISE composite) ───────────────
  Widget _statRow(SquadDayEntry e, bool showCalories) {
    final cols = <Widget>[
      if (showCalories)
        _stat('CONSUMED', e.consumed?.toStringAsFixed(0) ?? '–',
            member.effectiveGoal.calorieTarget != null
                ? '/ ${member.effectiveGoal.calorieTarget} kcal'
                : 'kcal'),
      _stat('EXERCISE', '${e.exerciseMinutes ?? 0}',
          'min · ${e.burned?.toStringAsFixed(0) ?? 0} kcal'),
    ];
    return Row(
      mainAxisAlignment:
          cols.length == 1 ? MainAxisAlignment.start : MainAxisAlignment.spaceAround,
      children: cols,
    );
  }

  Widget _stat(String label, String value, String unit) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text(value, style: AppText.tabular(AppText.displayM)),
        Text(unit, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
      ]);

  // ── 5/6. Meal + exercise timelines ────────────────────────────────────────
  Widget _meals(SquadDayEntry e) {
    final meals = e.meals ?? const [];
    if (meals.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: Spacing.s20),
      Text('MEALS', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      for (final m in meals)
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.s8),
          child: Row(children: [
            Expanded(child: Text(m.name, style: AppText.bodyS)),
            Text('${m.kcal.toStringAsFixed(0)} kcal  ${_fmt(m.time)}',
                style: AppText.tabular(AppText.bodyS.copyWith(color: AppColors.textSecondary))),
          ]),
        ),
    ]);
  }

  Widget _exercises(SquadDayEntry e) {
    final exercises = e.exercises ?? const [];
    if (exercises.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: Spacing.s20),
      Text('EXERCISES', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      for (final x in exercises)
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.s8),
          child: Row(children: [
            Expanded(child: Text(x.name, style: AppText.bodyS)),
            Text('${x.minutes} min · ${x.kcal.toStringAsFixed(0)} kcal  ${_fmt(x.time)}',
                style: AppText.tabular(AppText.bodyS.copyWith(color: AppColors.textSecondary))),
          ]),
        ),
    ]);
  }

  // ── 7. Weekly stats — only with ≥7 days of goal data ──────────────────────
  Widget _weeklyStats(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;
    if (myUid == null) return const SizedBox.shrink();
    return StreamBuilder<List<GoalVisible>>(
      stream: service.streamSquadmateGoalsVisible(member.uid, myUid),
      builder: (_, snap) {
        final goals = snap.data ?? const <GoalVisible>[];
        final distinctDays = goals.map((g) => g.date).toSet().length;
        if (distinctDays < 7) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: Spacing.s24),
          child: SquadmateGoalStats(goals: goals),
        );
      },
    );
  }

  // ── 8. Comments (sticky composer lives inside CommentThread) ──────────────
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

  Widget _suggestButton(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser?.uid;
    final myName = auth.appUser?.displayName ?? 'Athlete';
    if (myUid == null || member.uid == myUid) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s16),
      child: OutlinedButton.icon(
        onPressed: () async {
          final sent = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => GoalSuggestScreen(
                squadId: squadId, fromUid: myUid, fromName: myName,
                toUid: member.uid, toName: member.displayName,
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

  static String _fmt(DateTime? t) => t == null ? '' : DateFormat('HH:mm').format(t);
}
