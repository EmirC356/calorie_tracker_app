import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../screens/calendar/goal_edit_screen.dart';
import '../../screens/calendar/goal_create_screen.dart';
import '../../screens/calendar/recurring_edit_choice_sheet.dart';
import '../ui/ui.dart';
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
      backgroundColor: AppColors.surface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s24, vertical: Spacing.s32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(goal.title,
                textAlign: TextAlign.center, style: AppText.titleM),
            const SizedBox(height: Spacing.s8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: goal.color, shape: BoxShape.circle)),
              const SizedBox(width: Spacing.s4),
              Text('${goal.categoryLabel} · ${DateFormat('EEE, MMM d').format(date)}',
                  style: AppText.bodyS.copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: Spacing.s12),
            Center(
              child: StatusPill(
                status: occurrencePillStatus(status),
                label: occurrenceStatusLabel(status),
              ),
            ),
            if (goal.isTracked) _trackedProgress(context, provider),
            const SizedBox(height: Spacing.s20),
            _btn('Edit', LucideIcons.pencil, AppColors.calendarAmber,
                () => Navigator.pop(context, _ActionResult.edit)),
            const SizedBox(height: Spacing.s12),
            _btn('Mark done', LucideIcons.check, AppColors.statusHit,
                () => _setStatus(context, OccurrenceStatus.done)),
            const SizedBox(height: Spacing.s12),
            _btn('Mark failed', LucideIcons.x, AppColors.statusMissed,
                () => _setStatus(context, OccurrenceStatus.failed)),
            const SizedBox(height: Spacing.s12),
            _btn('Skip', LucideIcons.minusCircle, AppColors.statusPaused,
                () => _setStatus(context, OccurrenceStatus.skipped)),
            const SizedBox(height: Spacing.s12),
            _btn('Delete', LucideIcons.trash2, AppColors.statusMissed,
                () => Navigator.pop(context, _ActionResult.delete), destructive: true),
          ]),
        ),
      ),
    );
  }

  Widget _trackedProgress(BuildContext context, GoalProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s16),
      child: FutureBuilder<GoalEvaluationResult>(
        future: provider.evaluate(goal, date),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const ShimmerPlaceholder(height: 44, radius: AppRadius.r8);
          }
          final r = snap.data!;
          final pct = r.progressPercent ?? 0;
          final color = occurrenceStatusColor(r.status);
          return Row(children: [
            ProgressRing(percent: pct, color: color, centerLabel: '${pct.toStringAsFixed(0)}%'),
            const SizedBox(width: Spacing.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(goalTargetLabel(goal),
                    style: AppText.tabular(
                        AppText.bodyS.copyWith(color: goal.color))),
                const SizedBox(height: Spacing.s4),
                Text(
                  r.metricValue == null
                      ? (r.message ?? '—')
                      : '${r.metricValue!.toStringAsFixed(0)} / ${r.targetValue?.toStringAsFixed(0) ?? '—'}',
                  style: AppText.tabular(AppText.bodyM),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  /// Outlined full-width action. Non-destructive actions get a 1px border at
  /// 45% alpha; the destructive Delete gets a full 1.5px statusMissed border.
  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap,
          {bool destructive = false}) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label,
            style: AppText.bodyM
                .copyWith(color: color, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: color,
          side: destructive
              ? const BorderSide(
                  color: AppColors.statusMissed,
                  width: AppMotion.focusBorderWidth)
              : BorderSide(color: color.withValues(alpha: 0.45)),
        ),
      );
}
