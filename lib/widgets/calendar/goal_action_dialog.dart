import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../screens/calendar/goal_edit_screen.dart';
import '../../screens/calendar/goal_create_screen.dart';
import '../../screens/calendar/recurring_edit_choice_sheet.dart';
import 'calendar_status.dart';
import 'progress_ring.dart';

enum _ActionResult { edit, delete }

/// Tap a goal occurrence → this **centered modal dialog** (replaces the old
/// bottom sheet). Shows status + live tracked progress and the actions
/// Edit / Mark done / Mark failed / Skip / Delete. Edit and Delete route
/// recurring goals through the "only this / this and future / all" choice sheet.
Future<void> showGoalActionDialog(BuildContext context,
    {required Goal goal, required DateTime date}) async {
  final result = await showDialog<_ActionResult>(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    builder: (_) => _GoalActionDialog(goal: goal, date: date),
  );
  if (result == null || !context.mounted) return;
  if (result == _ActionResult.edit) {
    await _handleEdit(context, goal, date);
  } else {
    await _handleDelete(context, goal, date);
  }
}

bool _isRecurring(Goal g) => g.recurrence is! RecurrenceNone;

Future<void> _handleEdit(BuildContext context, Goal goal, DateTime date) async {
  final provider = context.read<GoalProvider>();
  if (!_isRecurring(goal)) {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => GoalEditScreen(goal: goal)));
    return;
  }
  final scope = await showRecurringEditChoice(context, verb: 'edit');
  if (scope == null || !context.mounted) return;
  switch (scope) {
    case RecurringEditScope.allInSeries:
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => GoalEditScreen(goal: goal)));
    case RecurringEditScope.thisAndFuture:
      // Edit the goal in the prefilled form; on save the series is split at
      // `date` (today INCLUSIVE) so today shows the new values immediately.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GoalEditScreen(
            goal: goal,
            onSubmit: (edited) => provider.editThisAndFuture(goal, date, edited),
          ),
        ),
      );
    case RecurringEditScope.onlyThis:
      // Hide this occurrence and create a one-off goal on this date to edit.
      await provider.setOccurrenceStatus(
          goalId: goal.id!, date: date, status: OccurrenceStatus.skipped);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GoalCreateScreen(
            template: goal.copyWith(
                clearId: true,
                startDate: date,
                recurrence: const RecurrenceNone(),
                clearEndDate: true),
          ),
        ),
      );
  }
}

Future<void> _handleDelete(BuildContext context, Goal goal, DateTime date) async {
  final provider = context.read<GoalProvider>();
  if (!_isRecurring(goal)) {
    await provider.deleteGoal(goal.id!);
    return;
  }
  final scope = await showRecurringEditChoice(context, verb: 'delete');
  if (scope == null) return;
  switch (scope) {
    case RecurringEditScope.allInSeries:
      await provider.deleteGoal(goal.id!);
    case RecurringEditScope.thisAndFuture:
      if (!date.isAfter(dateOnly(goal.startDate))) {
        await provider.deleteGoal(goal.id!); // from the start = whole series
      } else {
        await provider.truncateSeriesBefore(goal, date);
      }
    case RecurringEditScope.onlyThis:
      await provider.setOccurrenceStatus(
          goalId: goal.id!, date: date, status: OccurrenceStatus.skipped);
  }
}

class _GoalActionDialog extends StatelessWidget {
  final Goal goal;
  final DateTime date;
  const _GoalActionDialog({required this.goal, required this.date});

  bool get _periodOver {
    final period = goal.period ?? GoalPeriod.day;
    return !periodRange(period, date).endExclusive.isAfter(dateOnly(DateTime.now()));
  }

  Future<void> _setStatus(BuildContext context, OccurrenceStatus status) async {
    await context.read<GoalProvider>().setOccurrenceStatus(
          goalId: goal.id!,
          date: date,
          status: status,
          override: _periodOver,
        );
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    final row = goal.id == null ? null : provider.rowFor(goal.id!, date);
    final status = row?.status ?? OccurrenceStatus.open;
    final width = math.min(MediaQuery.of(context).size.width * 0.85, 360.0);

    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: goal.color.withValues(alpha: 0.6)),
      ),
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(goal.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: goal.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${goal.categoryLabel} · ${DateFormat('EEE, MMM d').format(date)}',
                  style: const TextStyle(color: kTextDim, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            _statusPill(status),
            if (goal.isTracked) _trackedProgress(context, provider),
            const SizedBox(height: 20),
            _btn('Edit', Icons.edit, kAmber, () => Navigator.pop(context, _ActionResult.edit)),
            const SizedBox(height: 12),
            _btn('Mark done', Icons.check_circle, const Color(0xFF4CC38A),
                () => _setStatus(context, OccurrenceStatus.done)),
            const SizedBox(height: 12),
            _btn('Mark failed', Icons.cancel, kNeonRed,
                () => _setStatus(context, OccurrenceStatus.failed)),
            const SizedBox(height: 12),
            _btn('Skip', Icons.remove_circle, kTextDim,
                () => _setStatus(context, OccurrenceStatus.skipped)),
            const SizedBox(height: 12),
            _btn('Delete', Icons.delete, kNeonRed,
                () => Navigator.pop(context, _ActionResult.delete), destructive: true),
          ]),
        ),
      ),
    );
  }

  Widget _statusPill(OccurrenceStatus status) {
    final color = occurrenceStatusColor(status);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(occurrenceStatusIcon(status), color: color, size: 16),
          const SizedBox(width: 6),
          Text(occurrenceStatusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _trackedProgress(BuildContext context, GoalProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FutureBuilder<GoalEvaluationResult>(
        future: provider.evaluate(goal, date),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const SizedBox(height: 44, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kAmber))));
          }
          final r = snap.data!;
          final pct = r.progressPercent ?? 0;
          final color = occurrenceStatusColor(r.status);
          return Row(children: [
            ProgressRing(percent: pct, color: color, centerLabel: '${pct.toStringAsFixed(0)}%'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(goalTargetLabel(goal), style: neonLabel(goal.color, size: 13)),
                const SizedBox(height: 4),
                Text(
                  r.metricValue == null
                      ? (r.message ?? '—')
                      : '${r.metricValue!.toStringAsFixed(0)} / ${r.targetValue?.toStringAsFixed(0) ?? '—'}',
                  style: const TextStyle(color: kText, fontSize: 14),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap,
          {bool destructive = false}) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: color.withValues(alpha: destructive ? 1.0 : 0.5)),
        ),
      );
}
