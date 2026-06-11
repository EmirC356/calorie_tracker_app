import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../providers/meal_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/exercise_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/shimmer_placeholder.dart';
import '../../widgets/edit_entry_sheets.dart';
import '../../widgets/calendar/day_goal_row.dart';
import '../../widgets/calendar/goal_action_dialog.dart';
import '../weight_tracker_screen.dart';

/// Single-day view: a Goals section (one row per occurrence) and an Activity
/// section (meals / exercises / weight, each linking to its edit flow).
class CalendarDayView extends StatelessWidget {
  final DateTime date;
  final VoidCallback onJumpToToday;
  const CalendarDayView({super.key, required this.date, required this.onJumpToToday});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    final occ = provider.occurrencesOn(date);
    final isToday = dateOnly(date) == dateOnly(DateTime.now());

    return ListView(padding: const EdgeInsets.all(Spacing.s16), children: [
      // Hero header: caption weekday over the displayL date.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE').format(date).toUpperCase(),
                style: AppText.caption),
            const SizedBox(height: Spacing.s4),
            Text(DateFormat('MMMM d').format(date),
                style: AppText.tabular(AppText.displayL)),
          ]),
        ),
        if (!isToday)
          TextButton.icon(
            onPressed: onJumpToToday,
            icon: const Icon(LucideIcons.calendarCheck,
                size: 16, color: AppColors.calendarAmber),
            label: Text('Today',
                style: AppText.bodyS
                    .copyWith(color: AppColors.calendarAmber)),
          ),
      ]),
      const SizedBox(height: Spacing.s20),
      Text('GOALS', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      if (occ.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.s12),
          child: Text('No goals scheduled',
              style: AppText.bodyM.copyWith(color: AppColors.textTertiary)),
        )
      else
        ...occ.map((o) => DayGoalRow(
              goal: o.goal,
              status: o.row?.status ?? OccurrenceStatus.open,
              onTap: () => showGoalActionDialog(context, goal: o.goal, date: date),
            )),
      const SizedBox(height: Spacing.s24),
      Text('ACTIVITY', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      FutureBuilder<({List<Meal> meals, List<Exercise> exercises, List<WeightEntry> weights})>(
        future: provider.dayDetail(date),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Column(children: [
              ShimmerPlaceholder.card(height: 56),
              SizedBox(height: Spacing.s8),
              ShimmerPlaceholder.card(height: 56),
            ]);
          }
          final d = snap.data!;
          if (d.meals.isEmpty && d.exercises.isEmpty && d.weights.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.s12),
              child: Text('Nothing logged this day',
                  style:
                      AppText.bodyM.copyWith(color: AppColors.textTertiary)),
            );
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...d.meals.map((m) => _activityRow(
                  LucideIcons.utensils, m.name,
                  '${m.nutrients.calories.toStringAsFixed(0)} kcal · P ${m.nutrients.protein.toStringAsFixed(0)}g',
                  m.timestamp,
                  () async {
                    final edited = await showEditMealSheet(context, m);
                    if (edited != null && context.mounted) {
                      await context.read<MealProvider>().updateMeal(edited);
                    }
                  },
                )),
            ...d.exercises.map((e) => _activityRow(
                  LucideIcons.dumbbell, e.name,
                  '${e.durationMinutes} min · ${e.caloriesBurned.toStringAsFixed(0)} kcal',
                  e.timestamp,
                  () async {
                    final edited = await showEditExerciseSheet(context, e);
                    if (edited != null && context.mounted) {
                      await context.read<ExerciseProvider>().updateExercise(edited);
                    }
                  },
                )),
            ...d.weights.map((w) => _activityRow(
                  LucideIcons.scale, '${w.weight.toStringAsFixed(1)} kg',
                  w.isEmptyStomach ? 'empty stomach' : 'weight entry',
                  w.timestamp,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightTrackerScreen())),
                )),
          ]);
        },
      ),
      const SizedBox(height: Spacing.s24),
    ]);
  }

  /// Timeline-style activity row, matching the Health meal/exercise lists:
  /// a 2px surface2 spine on the left, caption time chip, no card background.
  Widget _activityRow(IconData icon, String title, String subtitle,
          DateTime? time, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 2, color: AppColors.surface2),
            const SizedBox(width: Spacing.s12),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: Spacing.s8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Icon(icon,
                            color: AppColors.textSecondary, size: 16),
                        const SizedBox(width: Spacing.s8),
                        if (time != null)
                          Text(DateFormat('HH:mm').format(time),
                              style: AppText.tabular(AppText.caption)),
                      ]),
                      const SizedBox(height: Spacing.s4),
                      Text(title,
                          style: AppText.titleM,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(subtitle,
                          style: AppText.tabular(AppText.bodyS
                              .copyWith(color: AppColors.textSecondary))),
                    ]),
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                color: AppColors.textTertiary, size: 18),
          ]),
        ),
      );
}
