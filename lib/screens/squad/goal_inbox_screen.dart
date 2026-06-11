import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/colored_left_border_card.dart';
import '../../widgets/ui/shimmer_placeholder.dart';
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
      appBar: AppBar(title: const Text('Goal Inbox')),
      body: uid == null
          ? Center(
              child: Text('Sign in to see suggestions',
                  style: AppText.bodyM
                      .copyWith(color: AppColors.textSecondary)))
          : StreamBuilder<List<SquadGoalSuggestion>>(
              stream: service.streamPendingSuggestionsForMe(uid),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return ListView(
                    padding: const EdgeInsets.all(Spacing.s16),
                    children: const [
                      ShimmerPlaceholder.card(height: 140),
                      SizedBox(height: Spacing.s12),
                      ShimmerPlaceholder.card(height: 140),
                    ],
                  );
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s32),
          child: Text('No goal suggestions right now.',
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(Spacing.s16),
      children: suggestions.map((s) {
        final goal = _parse(s.payloadJson);
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.s12),
          child: ColoredLeftBorderCard(
            accent: AppColors.squadBlue,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.fromName} suggested a goal'.toUpperCase(),
                  style: AppText.caption),
              const SizedBox(height: Spacing.s8),
              if (goal == null)
                Text('(could not read this suggestion)',
                    style: AppText.bodyM
                        .copyWith(color: AppColors.textSecondary))
              else ...[
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: goal.color, shape: BoxShape.circle)),
                  const SizedBox(width: Spacing.s8),
                  Expanded(child: Text(goal.title, style: AppText.titleM)),
                ]),
                const SizedBox(height: Spacing.s4),
                Text('${goal.categoryLabel} · ${goalScheduleLabel(goal)}',
                    style: AppText.bodyS
                        .copyWith(color: AppColors.textSecondary)),
                if (goal.isTracked)
                  Text(goalTargetLabel(goal),
                      style: AppText.tabular(AppText.bodyS
                          .copyWith(color: AppColors.textSecondary))),
              ],
              const SizedBox(height: Spacing.s12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onAccept(s),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.squadBlue,
                        side: const BorderSide(
                            color: AppColors.squadBlue, width: 1.5)),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: Spacing.s8),
                OutlinedButton(
                  onPressed: () => onReject(s),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusMissed,
                      side: const BorderSide(
                          color: AppColors.statusMissed, width: 1.5)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: Spacing.s8),
                TextButton(
                  onPressed: () => onDismiss(s),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                  child: const Text('Dismiss'),
                ),
              ]),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
