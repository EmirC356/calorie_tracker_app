import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import 'goal_form_screen.dart';

/// Full-screen "edit a goal" form. Edits the whole goal definition (the series);
/// per-occurrence and "this and future" scopes are handled by the caller via
/// the recurring-edit-choice sheet before this screen is opened.
class GoalEditScreen extends StatelessWidget {
  final Goal goal;
  const GoalEditScreen({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return GoalFormScreen(
      appBarTitle: 'Edit Goal',
      submitLabel: 'SAVE',
      initial: goal,
      onSubmit: (g) => context.read<GoalProvider>().updateGoal(g),
    );
  }
}
