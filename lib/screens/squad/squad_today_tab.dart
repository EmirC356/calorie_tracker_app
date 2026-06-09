import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/squad_member.dart';
import '../../models/squad_day_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/snapshot_provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/snapshot_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/squad/member_card.dart';
import 'member_day_detail_screen.dart';

/// Today tab: a grid of member cards (avatar, goal, progress ring, status).
class SquadTodayTab extends StatefulWidget {
  final String squadId;
  const SquadTodayTab({super.key, required this.squadId});

  @override
  State<SquadTodayTab> createState() => _SquadTodayTabState();
}

class _SquadTodayTabState extends State<SquadTodayTab> {
  late final String _dateKey;

  @override
  void initState() {
    super.initState();
    _dateKey = SnapshotService.dateKey(DateTime.now());
    // Refresh my own snapshot so my card is current when the tab opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SnapshotProvider>().pushNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;

    return StreamBuilder<List<SquadMember>>(
      stream: service.watchMembers(widget.squadId),
      builder: (context, mSnap) {
        if (!mSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kNavy));
        }
        final members = mSnap.data!;
        return StreamBuilder<List<SquadDayEntry>>(
          stream: service.watchDayEntries(widget.squadId, _dateKey),
          builder: (context, eSnap) {
            final entries = {for (final e in (eSnap.data ?? const <SquadDayEntry>[])) e.uid: e};
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.82,
              ),
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                final entry = entries[m.uid];
                return MemberCard(
                  member: m,
                  entry: entry,
                  isMe: m.uid == myUid,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MemberDayDetailScreen(
                          member: m, entry: entry, squadId: widget.squadId, dateKey: _dateKey))),
                );
              },
            );
          },
        );
      },
    );
  }
}
