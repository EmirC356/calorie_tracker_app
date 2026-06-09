import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/calendar/calendar_status.dart';
import '../../widgets/calendar/progress_ring.dart';
import 'goal_edit_screen.dart';
import 'goal_create_screen.dart';
import 'recurring_edit_choice_sheet.dart';

enum _DetailResult { edit, delete }

/// Tap (or long-press) a goal chip → this sheet. Shows the occurrence's status,
/// live tracked-metric progress, and the actions Edit / Mark done / Mark failed
/// / Skip / Delete. Edit and Delete route recurring goals through the
/// "only this / this and future / all" choice sheet.
Future<void> showGoalDetailSheet(BuildContext context,
    {required Goal goal, required DateTime date}) async {
  final result = await showModalBottomSheet<_DetailResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: goal.color, width: 1),
    ),
    builder: (_) => _GoalDetailSheet(goal: goal, date: date),
  );
  if (result == null || !context.mounted) return;
  if (result == _DetailResult.edit) {
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
      // End the original series before this date, then create a fresh series
      // from this date the user can tweak.
      await provider.truncateSeriesBefore(goal, date);
      if (!context.mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  GoalCreateScreen(template: goal.copyWith(clearId: true, startDate: date))));
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
                      clearEndDate: true))));
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

class _GoalDetailSheet extends StatelessWidget {
  final Goal goal;
  final DateTime date;
  const _GoalDetailSheet({required this.goal, required this.date});

  bool get _periodOver {
    final period = goal.period ?? GoalPeriod.day;
    return !periodRange(period, date).endExclusive.isAfter(dateOnly(DateTime.now()));
  }

  Future<void> _setStatus(BuildContext context, OccurrenceStatus status) async {
    // A status change on an occurrence whose period has already ended is a
    // retroactive override.
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: goal.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(goal.title, style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold))),
            if (row?.overrideFlag == true)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('edited', style: TextStyle(color: kTextDim, fontSize: 11, fontStyle: FontStyle.italic)),
              ),
          ]),
          const SizedBox(height: 4),
          Text('${goal.categoryLabel} · ${goalScheduleLabel(goal)}',
              style: const TextStyle(color: kTextDim, fontSize: 12)),
          Text(DateFormat('EEEE, MMM d, yyyy').format(date),
              style: const TextStyle(color: kTextDim, fontSize: 12)),
          if (goal.description != null && goal.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(goal.description!, style: const TextStyle(color: kText, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Icon(occurrenceStatusIcon(status), color: occurrenceStatusColor(status), size: 18),
            const SizedBox(width: 6),
            Text(occurrenceStatusLabel(status),
                style: TextStyle(color: occurrenceStatusColor(status), fontWeight: FontWeight.bold)),
          ]),
          if (goal.isTracked) _trackedProgress(context, provider),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _action('Mark done', Icons.check_circle, const Color(0xFF4CC38A),
                () => _setStatus(context, OccurrenceStatus.done)),
            _action('Mark failed', Icons.cancel, kNeonRed,
                () => _setStatus(context, OccurrenceStatus.failed)),
            _action('Skip', Icons.remove_circle, kTextDim,
                () => _setStatus(context, OccurrenceStatus.skipped)),
            _action('Edit', Icons.edit, kAmber,
                () => Navigator.pop(context, _DetailResult.edit)),
            _action('Delete', Icons.delete, kNeonRed,
                () => Navigator.pop(context, _DetailResult.delete)),
          ]),
        ]),
      ),
    );
  }

  Widget _trackedProgress(BuildContext context, GoalProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
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

  Widget _action(String label, IconData icon, Color color, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: color.withValues(alpha: 0.6))),
      );
}
