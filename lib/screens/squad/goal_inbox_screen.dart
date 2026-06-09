import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/calendar/calendar_status.dart';
import '../calendar/goal_form_screen.dart';

/// Inbox of pending goal suggestions from squadmates. Accept opens the goal
/// form pre-filled (recipient can tweak, then it's added locally); Reject/Dismiss
/// drop it. Reached from the Squads tab badge.
class GoalInboxScreen extends StatelessWidget {
  const GoalInboxScreen({super.key});

  Goal? _parse(String payloadJson) {
    try {
      return Goal.fromJson(jsonDecode(payloadJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _accept(BuildContext context, SquadGoalSuggestion s) async {
    final parsed = _parse(s.payloadJson);
    if (parsed == null) return;
    // Clamp the start date to today so an accepted suggestion never lands in
    // the past (Phase 9 edge case), and let the recipient choose visibility.
    final today = dateOnly(DateTime.now());
    final start = parsed.startDate.isBefore(today) ? today : parsed.startDate;
    final goal = parsed.copyWith(clearId: true, startDate: start);
    final goalProvider = context.read<GoalProvider>();
    final service = context.read<SquadProvider>().service;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalFormScreen(
          appBarTitle: 'Accept goal',
          submitLabel: 'ADD GOAL',
          initial: goal,
          onSubmit: (g) async {
            await goalProvider.createGoal(g);
            await service.acceptSuggestion(s.squadId, s.id);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    final service = context.read<SquadProvider>().service;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GOAL INBOX'),
        titleTextStyle: const TextStyle(
            color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        iconTheme: const IconThemeData(color: kNavy),
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to see suggestions', style: TextStyle(color: kTextDim)))
          : StreamBuilder<List<SquadGoalSuggestion>>(
              stream: service.streamPendingSuggestionsForMe(uid),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kNavy));
                }
                final suggestions = snap.data ?? const [];
                return GoalInboxList(
                  suggestions: suggestions,
                  onAccept: (s) => _accept(context, s),
                  onReject: (s) => service.rejectSuggestion(s.squadId, s.id),
                  onDismiss: (s) => service.rejectSuggestion(s.squadId, s.id),
                );
              },
            ),
    );
  }
}

/// Pure list of pending suggestions (fed a fixed list), with accept/reject/
/// dismiss callbacks. Kept IO-free for easy widget testing.
class GoalInboxList extends StatelessWidget {
  final List<SquadGoalSuggestion> suggestions;
  final void Function(SquadGoalSuggestion) onAccept;
  final void Function(SquadGoalSuggestion) onReject;
  final void Function(SquadGoalSuggestion) onDismiss;

  const GoalInboxList({
    super.key,
    required this.suggestions,
    required this.onAccept,
    required this.onReject,
    required this.onDismiss,
  });

  Goal? _parse(String payloadJson) {
    try {
      return Goal.fromJson(jsonDecode(payloadJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No goal suggestions right now.', style: TextStyle(color: kTextDim)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: suggestions.map((s) {
        final goal = _parse(s.payloadJson);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: neonBox(kNavy),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.fromName} suggested a goal', style: neonLabel(kNavy, size: 12)),
            const SizedBox(height: 8),
            if (goal == null)
              const Text('(could not read this suggestion)', style: TextStyle(color: kTextDim))
            else ...[
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: goal.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(goal.title, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 4),
              Text('${goal.categoryLabel} · ${goalScheduleLabel(goal)}',
                  style: const TextStyle(color: kTextDim, fontSize: 12)),
              if (goal.isTracked)
                Text(goalTargetLabel(goal), style: const TextStyle(color: kTextDim, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onAccept(s),
                  style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: kWhite),
                  child: const Text('ACCEPT'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => onReject(s),
                style: OutlinedButton.styleFrom(foregroundColor: kNeonRed, side: const BorderSide(color: kNeonRed)),
                child: const Text('REJECT'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => onDismiss(s),
                style: TextButton.styleFrom(foregroundColor: kTextDim),
                child: const Text('DISMISS'),
              ),
            ]),
          ]),
        );
      }).toList(),
    );
  }
}
