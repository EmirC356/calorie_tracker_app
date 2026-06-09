import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/squad.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';
import 'squad_settings_screen.dart';

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
          _placeholder(Icons.today, "Today's progress", 'Member cards with goals, progress rings, and statuses arrive in the next update.'),
          _placeholder(Icons.leaderboard, 'Leaderboard', 'Weekly days-hit, current streak, and longest streak coming soon.'),
          SquadSettingsScreen(squadId: squadId),
        ]),
      ),
    );
  }

  Widget _placeholder(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: kNavy, size: 52),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: kTextDim, fontSize: 13, height: 1.5)),
        ]),
      );
}
