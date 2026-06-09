import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/weight_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_charts.dart';
import '../log_meal_screen.dart';
import '../meal_prep_screen.dart';
import '../exercise_logging_screen.dart';
import '../meal_logs_screen.dart';
import '../exercise_logs_screen.dart';
import '../profile_screen.dart';
import '../settings_screen.dart';

/// Dashboard sub-tab of the Health shell. Calorie/protein progress, trend
/// charts, and quick actions. The AppBar gear opens Settings (same as before);
/// Meal Prep moved here as an AppBar action when the bottom nav collapsed to
/// 3 tabs, and the Advisor chat icon was dropped because Advisor is now its
/// own Health sub-tab.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DASHBOARD'),
        actions: [
          IconButton(icon: const Icon(Icons.inventory_2), tooltip: 'Meal Prep',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPrepScreen()))),
          IconButton(icon: const Icon(Icons.person), tooltip: 'Profile & Goals',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          IconButton(icon: const Icon(Icons.settings), tooltip: 'Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("TODAY'S SUMMARY", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Consumer4<MealProvider, ExerciseProvider, ProfileProvider, WeightProvider>(
            builder: (_, meals, exercises, profileP, weightP, __) {
              final cal = meals.todaysTotalCalories;
              final pro = meals.todaysTotalProtein;
              final burned = exercises.todaysTotalCaloriesBurned;
              final net = cal - burned;
              final profile = profileP.profile;
              final weight = weightP.latest?.weight ?? profile?.fallbackWeightKg;
              final hasTargets = profileP.hasProfile && weight != null && weight > 0;
              final calTarget = hasTargets ? profile!.calorieTarget(weight) : null;
              final proTarget = hasTargets ? profile!.proteinTargetGrams(weight) : null;
              return Column(children: [
                _ProgressCard(label: 'Calories', consumed: cal, target: calTarget, unit: 'kcal', color: kCyan),
                const SizedBox(height: 8),
                _ProgressCard(label: 'Protein', consumed: pro, target: proTarget, unit: 'g', color: kNeonGreen),
                const SizedBox(height: 8),
                _summaryTile('Calories Burned', '${burned.toStringAsFixed(0)} kcal', kOrange),
                const SizedBox(height: 8),
                _summaryTile('Net Calories', '${net.toStringAsFixed(0)} kcal', net > 0 ? kNeonRed : kNeonGreen),
                if (!hasTargets) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Text('Set your profile to see calorie & protein targets →',
                      style: TextStyle(color: kCyan.withValues(alpha: 0.8), fontSize: 12)),
                  ),
                ],
              ]);
            },
          ),
          const SizedBox(height: 24),
          Text('TRENDS', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Consumer3<MealProvider, ProfileProvider, WeightProvider>(
            builder: (_, meals, profileP, weightP, __) {
              final profile = profileP.profile;
              final weight = weightP.latest?.weight ?? profile?.fallbackWeightKg;
              final goal = (profileP.hasProfile && weight != null && weight > 0)
                  ? profile!.calorieTarget(weight)
                  : null;
              return Column(children: [
                CollapsibleChartSection(
                  title: 'CALORIES — LAST 14 DAYS',
                  accent: kCyan,
                  initiallyExpanded: true,
                  child: CaloriesBarChart(totals: meals.dailyCalories(14), goal: goal),
                ),
                CollapsibleChartSection(
                  title: 'WEIGHT — LAST 90 DAYS',
                  accent: kNeonGreen,
                  child: WeightLineChart(entries: weightP.entries),
                ),
                CollapsibleChartSection(
                  title: "TODAY'S MACROS",
                  accent: kOrange,
                  child: MacrosDonut(
                    protein: meals.todaysTotalProtein,
                    carbs: meals.todaysTotalCarbs,
                    fat: meals.todaysTotalFat,
                  ),
                ),
              ]);
            },
          ),
          const SizedBox(height: 12),
          Text('QUICK ACTIONS', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _neonButton('Log Meal', Icons.add, kCyan,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogMealScreen())))),
            const SizedBox(width: 12),
            Expanded(child: _neonButton('Log Exercise', Icons.fitness_center, kPink,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLoggingScreen())))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _neonButton('Meal Logs', Icons.history, kNeonYellow,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealLogsScreen())))),
            const SizedBox(width: 12),
            Expanded(child: _neonButton('Exercise Logs', Icons.history, kPurple,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLogsScreen())))),
          ]),
        ]),
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: neonBox(color),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: kText, fontSize: 14)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, shadows: textGlow(color))),
      ]),
    );
  }

  Widget _neonButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: neonBox(color),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String label;
  final double consumed;
  final double? target;
  final String unit;
  final Color color;
  const _ProgressCard({
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = target != null && target! > 0;
    final ratio = hasTarget ? (consumed / target!).clamp(0.0, 1.0) : 0.0;
    final over = hasTarget && consumed > target!;
    final barColor = over ? kNeonRed : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: neonBox(color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: kText, fontSize: 14)),
          Text(
            hasTarget
                ? '${consumed.toStringAsFixed(0)} / ${target!.toStringAsFixed(0)} $unit'
                : '${consumed.toStringAsFixed(label == 'Protein' ? 1 : 0)} $unit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: barColor, shadows: textGlow(barColor)),
          ),
        ]),
        if (hasTarget) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: kBg,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            over
                ? '${(consumed - target!).toStringAsFixed(0)} $unit over target'
                : '${(target! - consumed).toStringAsFixed(0)} $unit left',
            style: const TextStyle(color: kTextDim, fontSize: 11),
          ),
        ],
      ]),
    );
  }
}
