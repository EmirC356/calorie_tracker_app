import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/index.dart';
import '../../providers/exercise_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/date_nav_bar.dart';
import '../../widgets/edit_entry_sheets.dart';
import '../../widgets/ui/section_nav.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/undo_delete.dart';
import '../exercise_logging_screen.dart';
import 'health_chips.dart';

/// Fitness sub-tab of the Health shell — the selected day's exercises as a
/// timeline (same treatment as Meals) with a date navigator to browse
/// previous days. The FAB always logs to today.
class FitnessTabScreen extends StatefulWidget {
  const FitnessTabScreen({super.key});

  @override
  State<FitnessTabScreen> createState() => _FitnessTabScreenState();
}

class _FitnessTabScreenState extends State<FitnessTabScreen> {
  late final ExerciseProvider _provider;
  DateTime _date = dateOnly(DateTime.now());
  List<Exercise> _exercises = [];

  bool get _isToday => _date == dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _provider = context.read<ExerciseProvider>();
    _provider.addListener(_reload);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _provider.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await _provider.getExercisesByDate(_date);
    if (mounted) setState(() => _exercises = list);
  }

  void _setDate(DateTime d) {
    setState(() => _date = d);
    _reload();
  }

  Future<void> _logExercise() async {
    await Navigator.push(
        context, HeroTransitionScaffold.route(const ExerciseLoggingScreen()));
    if (mounted) _setDate(dateOnly(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final accent = SectionAccent.of(context);
    return Scaffold(
      appBar: SectionAppBar(title: 'Fitness', accent: accent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DateNavBar(selected: _date, accent: accent, onChanged: _setDate),
          const SizedBox(height: Spacing.s12),
          if (_exercises.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(Spacing.s48),
              child: Text(
                  _isToday
                      ? 'No exercises logged today'
                      : 'No exercises logged on this day',
                  style:
                      AppText.bodyM.copyWith(color: AppColors.textTertiary)),
            ))
          else
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    left: BorderSide(color: AppColors.surface2, width: 2)),
              ),
              padding: const EdgeInsets.only(left: Spacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ex in _exercises)
                    _ExerciseTimelineEntry(
                      exercise: ex,
                      onDelete: () => deleteExerciseWithUndo(
                          ScaffoldMessenger.of(context), _provider, ex),
                      onEdit: (updated) => _provider.updateExercise(updated),
                    ),
                ],
              ),
            ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logExercise,
        backgroundColor: accent,
        foregroundColor: AppColors.surface0,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }
}

class _ExerciseTimelineEntry extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onDelete;
  final ValueChanged<Exercise> onEdit;
  const _ExerciseTimelineEntry(
      {required this.exercise, required this.onDelete, required this.onEdit});

  void _showDetail(BuildContext context) {
    final accent = SectionAccent.of(context);
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(Spacing.s20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(exercise.name, style: AppText.titleM),
          const SizedBox(height: Spacing.s4),
          Text(
              DateFormat('MMM d, HH:mm')
                  .format(exercise.timestamp)
                  .toUpperCase(),
              style: AppText.tabular(AppText.caption)),
          const SizedBox(height: Spacing.s16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            DetailChip(
                'Duration', '${exercise.durationMinutes} min', accent),
            DetailChip('Burned',
                '${exercise.caloriesBurned.toStringAsFixed(0)} kcal', accent),
            DetailChip('Intensity', exercise.intensity.toUpperCase(), accent),
          ]),
          const SizedBox(height: Spacing.s20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final edited = await showEditExerciseSheet(context, exercise);
                if (edited != null) onEdit(edited);
              },
              icon: const Icon(LucideIcons.pencil, size: 16),
              label: const Text('EDIT'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(
                      color: accent, width: AppMotion.focusBorderWidth)),
            )),
            const SizedBox(width: Spacing.s8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () { Navigator.pop(context); onDelete(); },
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('DELETE'),
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
    return GestureDetector(
      onTap: () => _showDetail(context),
      onLongPress: () => _showDetail(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Spacing.s20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.s8, vertical: Spacing.s4),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(DateFormat('HH:mm').format(exercise.timestamp),
                style: AppText.tabular(AppText.caption)),
          ),
          const SizedBox(height: Spacing.s8),
          Text(exercise.name,
              style: AppText.titleM, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: Spacing.s4),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(exercise.caloriesBurned.toStringAsFixed(0),
                    style: AppText.tabular(AppText.displayM)),
                const SizedBox(width: Spacing.s4),
                Text('kcal',
                    style:
                        AppText.bodyM.copyWith(color: AppColors.textTertiary)),
              ]),
          const SizedBox(height: Spacing.s8),
          Row(children: [
            StatBadge('${exercise.durationMinutes} min',
                AppColors.textSecondary),
            const SizedBox(width: Spacing.s8),
            StatBadge(exercise.intensity.toUpperCase(),
                AppColors.textSecondary),
          ]),
        ]),
      ),
    );
  }
}
