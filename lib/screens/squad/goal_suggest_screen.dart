import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/squad_provider.dart';
import '../calendar/goal_form_screen.dart';

/// "Suggest a goal" form for a squadmate. Reuses the goal form with the
/// squad-visible toggle hidden — the recipient decides visibility on accept.
/// Pops with `true` after the suggestion is sent.
class GoalSuggestScreen extends StatelessWidget {
  final String squadId;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;

  const GoalSuggestScreen({
    super.key,
    required this.squadId,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    return GoalFormScreen(
      appBarTitle: 'Suggest to $toName',
      submitLabel: 'SEND SUGGESTION',
      showSquadVisible: false,
      onSubmit: (goal) => service.suggestGoal(
        squadId: squadId,
        fromUid: fromUid,
        fromName: fromName,
        toUid: toUid,
        payloadJson: jsonEncode(goal.toJson()),
      ),
    );
  }
}
