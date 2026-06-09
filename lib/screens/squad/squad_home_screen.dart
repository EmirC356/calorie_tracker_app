import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';
import 'squad_settings_screen.dart';
import 'squad_today_tab.dart';
import 'squad_board_tab.dart';

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
          iconTheme: const IconThemeData(color: kNavy),
          titleTextStyle: const TextStyle(color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4),
          title: StreamBuilder<Squad?>(
            stream: service.watchSquad(squadId),
            builder: (_, snap) => Text(snap.data?.name.toUpperCase() ?? 'SQUAD'),
          ),
          bottom: const TabBar(
            labelColor: kNavy,
            unselectedLabelColor: kTextDim,
            indicatorColor: kNavy,
            tabs: [Tab(text: 'TODAY'), Tab(text: 'BOARD'), Tab(text: 'SETTINGS')],
          ),
        ),
        body: TabBarView(children: [
          SquadTodayTab(squadId: squadId),
          SquadBoardTab(squadId: squadId),
          SquadSettingsScreen(squadId: squadId),
        ]),
      ),
    );
  }
}
