import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edit_entry_sheets.dart';
import '../../widgets/calendar/day_goal_row.dart';
import '../weight_tracker_screen.dart';
import 'goal_detail_sheet.dart';

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

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE').format(date), style: neonLabel(kAmber, size: 18)),
            Text(DateFormat('MMMM d, yyyy').format(date),
                style: const TextStyle(color: kTextDim, fontSize: 13)),
          ]),
        ),
        if (!isToday)
          TextButton.icon(
            onPressed: onJumpToToday,
            icon: const Icon(Icons.today, size: 16, color: kAmber),
            label: const Text('Today', style: TextStyle(color: kAmber)),
          ),
      ]),
      const SizedBox(height: 16),
      Text('GOALS', style: neonLabel(kAmber, size: 13)),
      const SizedBox(height: 8),
      if (occ.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('No goals scheduled', style: TextStyle(color: kTextDim, fontSize: 13)),
        )
      else
        ...occ.map((o) => DayGoalRow(
              goal: o.goal,
              status: o.row?.status ?? OccurrenceStatus.open,
              onTap: () => showGoalDetailSheet(context, goal: o.goal, date: date),
            )),
      const SizedBox(height: 24),
      Text('ACTIVITY', style: neonLabel(kAmber, size: 13)),
      const SizedBox(height: 8),
      FutureBuilder<({List<Meal> meals, List<Exercise> exercises, List<WeightEntry> weights})>(
        future: provider.dayDetail(date),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kAmber))),
            );
          }
          final d = snap.data!;
          if (d.meals.isEmpty && d.exercises.isEmpty && d.weights.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nothing logged this day', style: TextStyle(color: kTextDim, fontSize: 13)),
            );
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...d.meals.map((m) => _activityRow(
                  Icons.restaurant, kCyan, m.name,
                  '${m.nutrients.calories.toStringAsFixed(0)} kcal · P ${m.nutrients.protein.toStringAsFixed(0)}g',
                  () async {
                    final edited = await showEditMealSheet(context, m);
                    if (edited != null && context.mounted) {
                      await context.read<MealProvider>().updateMeal(edited);
                    }
                  },
                )),
            ...d.exercises.map((e) => _activityRow(
                  Icons.fitness_center, kPink, e.name,
                  '${e.durationMinutes} min · ${e.caloriesBurned.toStringAsFixed(0)} kcal',
                  () async {
                    final edited = await showEditExerciseSheet(context, e);
                    if (edited != null && context.mounted) {
                      await context.read<ExerciseProvider>().updateExercise(edited);
                    }
                  },
                )),
            ...d.weights.map((w) => _activityRow(
                  Icons.monitor_weight, kNeonGreen, '${w.weight.toStringAsFixed(1)} kg',
                  w.isEmptyStomach ? 'empty stomach' : 'weight entry',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightTrackerScreen())),
                )),
          ]);
        },
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _activityRow(IconData icon, Color color, String title, String subtitle, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: neonBox(color),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: kTextDim, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: kTextDim, size: 18),
          ]),
        ),
      );
}
