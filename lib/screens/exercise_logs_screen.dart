import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/index.dart';
import '../providers/exercise_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/edit_entry_sheets.dart';
import '../widgets/undo_delete.dart';

/// Historical exercise list for any date, as a timeline (no card chrome) with
/// the detail sheet and a tabular totals footer.
class ExerciseLogsScreen extends StatefulWidget {
  const ExerciseLogsScreen({super.key});

  @override
  State<ExerciseLogsScreen> createState() => _ExerciseLogsScreenState();
}

class _ExerciseLogsScreenState extends State<ExerciseLogsScreen> {
  static const _accent = AppColors.healthRed;

  DateTime _selectedDate = DateTime.now();
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exercises = await context.read<ExerciseProvider>().getExercisesByDate(_selectedDate);
    if (mounted) setState(() => _exercises = exercises);
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(data: Theme.of(context), child: child!),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  void _showDetail(Exercise ex) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(Spacing.s20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ex.name, style: AppText.titleM),
          const SizedBox(height: Spacing.s4),
          Text(DateFormat('MMM d, HH:mm').format(ex.timestamp).toUpperCase(),
              style: AppText.tabular(AppText.caption)),
          const SizedBox(height: Spacing.s16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _KeyValue('Duration', '${ex.durationMinutes} min'),
            _KeyValue('Burned', '${ex.caloriesBurned.toStringAsFixed(0)} kcal'),
            _KeyValue('Intensity', ex.intensity.toUpperCase()),
          ]),
          if (ex.notes != null && ex.notes!.isNotEmpty) ...[
            const SizedBox(height: Spacing.s12),
            Text(ex.notes!,
                style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: Spacing.s20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                final provider = context.read<ExerciseProvider>();
                Navigator.pop(context);
                final edited = await showEditExerciseSheet(context, ex);
                if (edited != null) {
                  await provider.updateExercise(edited);
                  if (mounted) _load();
                }
              },
              icon: const Icon(LucideIcons.pencil, size: 16),
              label: const Text('EDIT'),
            )),
            const SizedBox(width: Spacing.s8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final provider = context.read<ExerciseProvider>();
                Navigator.pop(context);
                deleteExerciseWithUndo(messenger, provider, ex,
                    afterChange: () async { if (mounted) _load(); });
              },
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('DELETE'),
              // Destructive: 1.5px statusMissed border, never a red fill.
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusMissed,
                  side: const BorderSide(
                      color: AppColors.statusMissed,
                      width: AppMotion.focusBorderWidth)),
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalCal = 0;
    int totalDur = 0;
    for (final e in _exercises) {
      totalCal += e.caloriesBurned;
      totalDur += e.durationMinutes;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Logs'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: Spacing.s16),
              child: SizedBox(
                  width: Spacing.s48,
                  height: 2,
                  child: ColoredBox(color: _accent)),
            ),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s16, vertical: Spacing.s8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
                DateFormat('MMM dd, yyyy')
                    .format(_selectedDate)
                    .toUpperCase(),
                style: AppText.tabular(AppText.caption)),
            OutlinedButton(onPressed: _pickDate, child: const Text('Change Date')),
          ]),
        ),
        Expanded(
          child: _exercises.isEmpty
            ? Center(
                child: Text('No exercises on this date',
                    style:
                        AppText.bodyM.copyWith(color: AppColors.textTertiary)))
            : ListView.builder(
                padding: const EdgeInsets.all(Spacing.s16),
                itemCount: _exercises.length,
                itemBuilder: (_, i) {
                  final ex = _exercises[i];
                  return GestureDetector(
                    onTap: () => _showDetail(ex),
                    onLongPress: () => _showDetail(ex),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                            left: BorderSide(
                                color: AppColors.surface2, width: 2)),
                      ),
                      padding: const EdgeInsets.only(
                          left: Spacing.s16, bottom: Spacing.s20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Spacing.s8,
                                  vertical: Spacing.s4),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                  DateFormat('HH:mm').format(ex.timestamp),
                                  style: AppText.tabular(AppText.caption)),
                            ),
                            const SizedBox(height: Spacing.s8),
                            Text(ex.name,
                                style: AppText.titleM,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: Spacing.s4),
                            Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                      ex.caloriesBurned.toStringAsFixed(0),
                                      style: AppText.tabular(
                                          AppText.displayM)),
                                  const SizedBox(width: Spacing.s4),
                                  Text('kcal',
                                      style: AppText.bodyM.copyWith(
                                          color: AppColors.textTertiary)),
                                ]),
                            const SizedBox(height: Spacing.s8),
                            Row(children: [
                              _chip('${ex.durationMinutes} min'),
                              const SizedBox(width: Spacing.s8),
                              _chip(ex.intensity.toUpperCase()),
                            ]),
                          ]),
                    ),
                  );
                },
              ),
        ),
        if (_exercises.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(Spacing.s16),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppColors.surface2, width: 1)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _KeyValue('Duration', '$totalDur min'),
              _KeyValue('Burned', '${totalCal.toStringAsFixed(0)} kcal'),
              _KeyValue('Sessions', '${_exercises.length}'),
            ]),
          ),
      ]),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s8, vertical: Spacing.s4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Text(text,
            style: AppText.tabular(
                AppText.bodyS.copyWith(color: AppColors.textSecondary))),
      );
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValue(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label.toUpperCase(), style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text(value, style: AppText.tabular(AppText.titleM)),
      ]);
}
