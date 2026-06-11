import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../models/squad_day_entry.dart';
import '../../models/squad_goal.dart';
import '../../providers/squad_provider.dart';
import '../../services/snapshot_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'squad_settings_screen.dart';
import 'squad_today_tab.dart';
import 'squad_board_tab.dart';
import '../../widgets/squad/photo_strip.dart';

/// A single squad with three tabs. Today (Phase 4) and Leaderboard (Phase 6)
/// are placeholders for now; Settings (Phase 3) is live.
class SquadHomeScreen extends StatelessWidget {
  final String squadId;
  const SquadHomeScreen({super.key, required this.squadId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<Squad?>(
            stream: service.watchSquad(squadId),
            builder: (_, snap) {
              final squad = snap.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(squad?.name ?? 'Squad'),
                  if (squad != null)
                    StreamBuilder<List<SquadDayEntry>>(
                      stream: service.watchDayEntries(
                          squadId, SnapshotService.dateKey(DateTime.now())),
                      builder: (_, eSnap) {
                        final hits = (eSnap.data ?? const <SquadDayEntry>[])
                            .where((e) => e.status == GoalStatus.hit && !e.paused)
                            .length;
                        return Text(
                          '${squad.memberCount} members · $hits/${squad.memberCount} hit today',
                          style: AppText.caption.copyWith(color: AppColors.textSecondary),
                        );
                      },
                    ),
                ],
              );
            },
          ),
          bottom: TabBar(
            labelColor: AppColors.squadBlue,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.squadBlue,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppColors.divider,
            dividerHeight: 1,
            labelStyle: AppText.bodyS,
            unselectedLabelStyle: AppText.bodyS,
            tabs: const [
              Tab(text: 'TODAY'),
              Tab(text: 'BOARD'),
              Tab(text: 'SETTINGS')
            ],
          ),
        ),
        body: TabBarView(children: [
          SquadTodayTab(squadId: squadId),
          SquadBoardTab(squadId: squadId),
          SquadSettingsScreen(squadId: squadId),
        ]),
        // Proof — camera to take a photo; viewing is per-member (tap an avatar).
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.squadBlue,
          foregroundColor: AppColors.surface0,
          onPressed: () => launchProofCamera(context, squadId),
          child: const Icon(LucideIcons.camera),
        ),
      ),
    );
  }
}
