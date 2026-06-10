import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import 'goal_form_screen.dart';

/// Full-screen "edit a goal" form. Defaults to editing the whole series; the
/// caller can pass [onSubmit] to apply a narrower scope (e.g. "this and future"
/// passes editThisAndFuture so the split happens on save).
class GoalEditScreen extends StatelessWidget {
  final Goal goal;
  final Future<void> Function(Goal goal)? onSubmit;
  const GoalEditScreen({super.key, required this.goal, this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return GoalFormScreen(
      appBarTitle: 'Edit Goal',
      submitLabel: 'SAVE',
      initial: goal,
      onSubmit: onSubmit ?? (g) => context.read<GoalProvider>().updateGoal(g),
    );
  }
}
