import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_goal.dart';
import '../../models/squad_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/snapshot_service.dart';
import '../../theme/app_theme.dart';

class _Row {
  final SquadMember member;
  final MemberStreak streak;
  const _Row(this.member, this.streak);
}

/// Leaderboard: days-hit (last 7), current streak, longest streak per member.
/// Loads the last [_window] days of entries once on open (cheap, small docs).
class SquadBoardTab extends StatefulWidget {
  final String squadId;
  const SquadBoardTab({super.key, required this.squadId});

  @override
  State<SquadBoardTab> createState() => _SquadBoardTabState();
}

class _SquadBoardTabState extends State<SquadBoardTab> {
  static const int _window = 30;
  bool _loading = true;
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

    // Fetch all days in parallel; collect each member's hit-days.
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: kNavy));
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;
    return RefreshIndicator(
      color: kNavy,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('LAST 7 DAYS  ·  STREAKS', style: neonLabel(kNavy, size: 12)),
          const SizedBox(height: 12),
          ..._rows.asMap().entries.map((e) => _row(e.key + 1, e.value, e.value.member.uid == myUid)),
        ],
      ),
    );
  }

  Widget _row(int rank, _Row r, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: neonBox(isMe ? kNavy : kBorderDim),
      child: Row(children: [
        SizedBox(
          width: 24,
          child: Text('$rank', style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        CircleAvatar(
          radius: 18, backgroundColor: kSurface,
          backgroundImage: (r.member.photoURL?.isNotEmpty ?? false) ? NetworkImage(r.member.photoURL!) : null,
          child: (r.member.photoURL?.isEmpty ?? true) ? const Icon(Icons.person, color: kNavy, size: 18) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isMe ? '${r.member.displayName} (you)' : r.member.displayName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kText, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('${r.streak.daysHitLast7}/7 days hit  ·  longest ${r.streak.longestStreak}',
                style: const TextStyle(color: kTextDim, fontSize: 12)),
          ]),
        ),
        Column(children: [
          Text('🔥 ${r.streak.currentStreak}', style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 16)),
          const Text('streak', style: TextStyle(color: kTextDim, fontSize: 10)),
        ]),
      ]),
    );
  }
}
