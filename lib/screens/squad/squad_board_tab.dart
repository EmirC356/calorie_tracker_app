import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_goal.dart';
import '../../models/squad_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/snapshot_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/member_avatar.dart';
import '../../widgets/ui/shimmer_placeholder.dart';

class _Row {
  final SquadMember member;
  final MemberStreak streak;
  const _Row(this.member, this.streak);
}

/// Leaderboard as a proportional streak-bar chart: one horizontal bar per
/// member (width ∝ their current streak vs the squad's longest), sorted streak
/// DESC. Paused members collapse into a section at the foot.
class SquadBoardTab extends StatefulWidget {
  final String squadId;
  const SquadBoardTab({super.key, required this.squadId});

  @override
  State<SquadBoardTab> createState() => _SquadBoardTabState();
}

class _SquadBoardTabState extends State<SquadBoardTab> {
  static const int _window = 30;
  bool _loading = true;
  bool _pausedExpanded = false;
  List<_Row> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = context.read<SquadProvider>().service;
    final today = DateTime.now();

    final members = await service.watchMembers(widget.squadId).first;
    final dates = [for (var i = 0; i < _window; i++) today.subtract(Duration(days: i))];
    final perDay = await Future.wait(
        dates.map((d) => service.getDayEntries(widget.squadId, SnapshotService.dateKey(d))));

    final hitDays = <String, Set<DateTime>>{};
    for (var i = 0; i < dates.length; i++) {
      final day = DateTime(dates[i].year, dates[i].month, dates[i].day);
      for (final SquadDayEntry e in perDay[i]) {
        if (e.status == GoalStatus.hit) {
          hitDays.putIfAbsent(e.uid, () => {}).add(day);
        }
      }
    }

    final rows = members
        .map((m) => _Row(m, computeStreak(hitDays[m.uid] ?? <DateTime>{}, today, window: _window)))
        .toList()
      ..sort((a, b) {
        final byCurrent = b.streak.currentStreak.compareTo(a.streak.currentStreak);
        if (byCurrent != 0) return byCurrent;
        final byWeek = b.streak.daysHitLast7.compareTo(a.streak.daysHitLast7);
        if (byWeek != 0) return byWeek;
        return a.member.displayName.toLowerCase().compareTo(b.member.displayName.toLowerCase());
      });

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(padding: const EdgeInsets.all(Spacing.s16), children: const [
        ShimmerPlaceholder.line(width: 160),
        SizedBox(height: Spacing.s12),
        ShimmerPlaceholder.card(height: 72),
        SizedBox(height: Spacing.s8),
        ShimmerPlaceholder.card(height: 72),
        SizedBox(height: Spacing.s8),
        ShimmerPlaceholder.card(height: 72),
      ]);
    }
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;
    final now = DateTime.now();
    final active = _rows.where((r) => !r.member.pause.isCurrentlyPaused(now)).toList();
    final paused = _rows.where((r) => r.member.pause.isCurrentlyPaused(now)).toList();
    final maxStreak =
        active.isEmpty ? 0 : active.map((r) => r.streak.currentStreak).reduce(math.max);

    return RefreshIndicator(
      color: AppColors.squadBlue,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(Spacing.s16), children: [
        Text('CURRENT STREAKS', style: AppText.caption),
        const SizedBox(height: Spacing.s12),
        if (active.isNotEmpty && maxStreak == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.s12),
            child: Text('No streaks yet — be the first 🔥',
                style: AppText.bodyM.copyWith(color: AppColors.textTertiary)),
          ),
        for (final r in active) _barRow(r, maxStreak, r.member.uid == myUid),
        if (paused.isNotEmpty) _pausedSection(paused, myUid),
      ]),
    );
  }

  Widget _barRow(_Row r, int maxStreak, bool isMe) {
    final streak = r.streak.currentStreak;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s8),
      padding: const EdgeInsets.all(Spacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: isMe
            ? Border.all(color: AppColors.squadBlue, width: AppMotion.focusBorderWidth)
            : null,
        boxShadow: isMe ? AppMotion.accentGlow(AppColors.squadBlue) : null,
      ),
      child: Row(children: [
        MemberAvatar(
          photoURL: (r.member.photoURL?.isNotEmpty ?? false) ? r.member.photoURL : null,
          displayName: r.member.displayName,
          currentStreak: streak.toDouble(),
          lastActiveDate: r.member.lastActivityAt,
          size: 36,
        ),
        const SizedBox(width: Spacing.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(isMe ? '${r.member.displayName} (you)' : r.member.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleM),
              ),
              Text('$streak',
                  style: AppText.tabular(AppText.titleL.copyWith(color: AppColors.squadBlue))),
              const SizedBox(width: Spacing.s4),
              Text(streak == 1 ? 'day' : 'days', style: AppText.caption),
            ]),
            const SizedBox(height: Spacing.s8),
            _bar(streak, maxStreak),
            const SizedBox(height: Spacing.s4),
            Text('longest ${r.streak.longestStreak}  ·  ${r.streak.daysHitLast7}/7 this week',
                style: AppText.tabular(AppText.caption)),
          ]),
        ),
      ]),
    );
  }

  Widget _bar(int streak, int maxStreak) {
    final frac = maxStreak <= 0 ? 0.0 : (streak / maxStreak).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        height: 24,
        alignment: Alignment.centerLeft,
        color: AppColors.surface2,
        child: FractionallySizedBox(
          widthFactor: frac,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.squadBlue,
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pausedSection(List<_Row> paused, String? myUid) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: Spacing.s8),
      InkWell(
        onTap: () => setState(() => _pausedExpanded = !_pausedExpanded),
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
          child: Row(children: [
            Text('PAUSED (${paused.length})', style: AppText.caption),
            const Spacer(),
            Icon(_pausedExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 16, color: AppColors.textTertiary),
          ]),
        ),
      ),
      if (_pausedExpanded)
        for (final r in paused)
          Container(
            margin: const EdgeInsets.only(bottom: Spacing.s8),
            padding: const EdgeInsets.all(Spacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: r.member.uid == myUid
                  ? Border.all(color: AppColors.squadBlue, width: AppMotion.focusBorderWidth)
                  : null,
            ),
            child: Row(children: [
              MemberAvatar(
                photoURL: (r.member.photoURL?.isNotEmpty ?? false) ? r.member.photoURL : null,
                displayName: r.member.displayName,
                paused: true,
                size: 36,
              ),
              const SizedBox(width: Spacing.s12),
              Expanded(
                child: Text(r.member.uid == myUid ? '${r.member.displayName} (you)' : r.member.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleM),
              ),
              Text('🌴', style: const TextStyle(fontSize: 18)),
            ]),
          ),
    ]);
  }
}
