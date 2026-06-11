import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import 'goal_form_screen.dart';

/// Full-screen "create a goal" form. Optionally pre-fills from [template]
/// (used by the empty-state example goals).
class GoalCreateScreen extends StatelessWidget {
  final Goal? template;

  /// Pre-fills the start date (e.g. the calendar day in view). Null = today.
  final DateTime? defaultStartDate;
  const GoalCreateScreen({super.key, this.template, this.defaultStartDate});

  @override
  Widget build(BuildContext context) {
    return GoalFormScreen(
      appBarTitle: 'New Goal',
      submitLabel: 'CREATE',
      initial: template,
      defaultStartDate: defaultStartDate,
      onSubmit: (goal) => context.read<GoalProvider>().createGoal(goal),
    );
  }
}
