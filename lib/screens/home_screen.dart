import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/meal_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/weight_provider.dart';
import '../models/index.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_entry_sheets.dart';
import 'log_meal_screen.dart';
import 'meal_prep_screen.dart';
import 'weight_tracker_screen.dart';
import 'exercise_logging_screen.dart';
import 'meal_logs_screen.dart';
import 'exercise_logs_screen.dart';
import 'meal_advice_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Capture providers synchronously, then load after the first frame so we
    // don't notifyListeners() mid-build.
    final meals = context.read<MealProvider>();
    final exercises = context.read<ExerciseProvider>();
    final profile = context.read<ProfileProvider>();
    final weight = context.read<WeightProvider>();
    Future.microtask(() {
      meals.loadTodaysMeals();
      exercises.loadTodaysExercises();
      profile.load();
      weight.loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Meals'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Prep'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_weight), label: 'Weight'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Fitness'),
        ],
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return const _DashboardScreen();
      case 1: return const _MealTrackerScreen();
      case 2: return const MealPrepScreen();
      case 3: return const WeightTrackerScreen();
      case 4: return const _FitnessTrackerScreen();
      default: return const _DashboardScreen();
    }
  }
}

// ── Dashboard ──────────────────────────────────────────────────────────────────
class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DASHBOARD'),
        actions: [
          IconButton(icon: const Icon(Icons.chat), tooltip: 'Meal Advisor',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealAdviceScreen()))),
          IconButton(icon: const Icon(Icons.person), tooltip: 'Profile & Goals',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          IconButton(icon: const Icon(Icons.settings),
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
                _SummaryTile('Calories Burned', '${burned.toStringAsFixed(0)} kcal', kOrange),
                const SizedBox(height: 8),
                _SummaryTile('Net Calories', '${net.toStringAsFixed(0)} kcal', net > 0 ? kNeonRed : kNeonGreen),
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
          Text('QUICK ACTIONS', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _NeonButton('Log Meal', Icons.add, kCyan,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogMealScreen())))),
            const SizedBox(width: 12),
            Expanded(child: _NeonButton('Log Exercise', Icons.fitness_center, kPink,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLoggingScreen())))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _NeonButton('Meal Logs', Icons.history, kNeonYellow,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealLogsScreen())))),
            const SizedBox(width: 12),
            Expanded(child: _NeonButton('Exercise Logs', Icons.history, kPurple,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLogsScreen())))),
          ]),
        ]),
      ),
    );
  }

  Widget _SummaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: neonBox(color),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: kText, fontSize: 14)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, shadows: textGlow(color))),
      ]),
    );
  }

  Widget _NeonButton(String label, IconData icon, Color color, VoidCallback onTap) {
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

// ── Meal Tracker ────────────────────────────────────────────────────────────────
class _MealTrackerScreen extends StatelessWidget {
  const _MealTrackerScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MEALS TODAY')),
      body: Consumer<MealProvider>(
        builder: (_, mp, __) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (mp.todaysMeals.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No meals logged today', style: Theme.of(context).textTheme.bodySmall),
              ))
            else
              ...mp.todaysMeals.map((meal) => _MealCard(
                    meal: meal,
                    onDelete: () => mp.deleteMeal(meal.id!),
                    onEdit: (updated) => mp.updateMeal(updated),
                  )),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogMealScreen())),
        backgroundColor: kCyan,
        foregroundColor: kBg,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onDelete;
  final ValueChanged<Meal> onEdit;
  const _MealCard({required this.meal, required this.onDelete, required this.onEdit});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kCyan, width: 1)),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meal.name, style: neonLabel(kCyan, size: 15), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(DateFormat('MMM d, HH:mm').format(meal.timestamp), style: const TextStyle(color: kTextDim, fontSize: 12)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _DetailChip('Calories', '${meal.nutrients.calories.toStringAsFixed(0)} kcal', kCyan),
            _DetailChip('Protein', '${meal.nutrients.protein.toStringAsFixed(1)}g', kNeonRed),
            _DetailChip('Carbs', '${meal.nutrients.carbohydrates.toStringAsFixed(1)}g', kNeonYellow),
            _DetailChip('Fat', '${meal.nutrients.fat.toStringAsFixed(1)}g', kOrange),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final edited = await showEditMealSheet(context, meal);
                if (edited != null) onEdit(edited);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('EDIT'),
              style: OutlinedButton.styleFrom(foregroundColor: kCyan, side: const BorderSide(color: kCyan)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); onDelete(); },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('DELETE'),
              style: ElevatedButton.styleFrom(backgroundColor: kNeonRed, foregroundColor: Colors.white),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: neonBox(kCyan),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meal.name, style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            _Badge('${meal.nutrients.calories.toStringAsFixed(0)} kcal', kCyan),
            const SizedBox(width: 6),
            _Badge('P ${meal.nutrients.protein.toStringAsFixed(1)}g', kNeonRed),
            const SizedBox(width: 6),
            _Badge('C ${meal.nutrients.carbohydrates.toStringAsFixed(1)}g', kNeonYellow),
            const Spacer(),
            Text(DateFormat('HH:mm').format(meal.timestamp), style: const TextStyle(color: kTextDim, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

// ── Fitness Tracker ─────────────────────────────────────────────────────────────
class _FitnessTrackerScreen extends StatelessWidget {
  const _FitnessTrackerScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FITNESS TODAY'),
        titleTextStyle: const TextStyle(color: kPink, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, shadows: [Shadow(color: kPink, blurRadius: 8)])),
      body: Consumer<ExerciseProvider>(
        builder: (_, ep, __) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (ep.todaysExercises.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No exercises logged today', style: Theme.of(context).textTheme.bodySmall),
              ))
            else
              ...ep.todaysExercises.map((ex) => _ExerciseCard(
                    exercise: ex,
                    onDelete: () => ep.deleteExercise(ex.id!),
                    onEdit: (updated) => ep.updateExercise(updated),
                  )),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLoggingScreen())),
        backgroundColor: kPink,
        foregroundColor: kBg,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onDelete;
  final ValueChanged<Exercise> onEdit;
  const _ExerciseCard({required this.exercise, required this.onDelete, required this.onEdit});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kPink, width: 1)),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(exercise.name, style: neonLabel(kPink, size: 15)),
          const SizedBox(height: 4),
          Text(DateFormat('MMM d, HH:mm').format(exercise.timestamp), style: const TextStyle(color: kTextDim, fontSize: 12)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _DetailChip('Duration', '${exercise.durationMinutes} min', kPink),
            _DetailChip('Burned', '${exercise.caloriesBurned.toStringAsFixed(0)} kcal', kOrange),
            _DetailChip('Intensity', exercise.intensity.toUpperCase(), kNeonGreen),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final edited = await showEditExerciseSheet(context, exercise);
                if (edited != null) onEdit(edited);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('EDIT'),
              style: OutlinedButton.styleFrom(foregroundColor: kPink, side: const BorderSide(color: kPink)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); onDelete(); },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('DELETE'),
              style: ElevatedButton.styleFrom(backgroundColor: kNeonRed, foregroundColor: Colors.white),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: neonBox(kPink),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exercise.name, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${exercise.durationMinutes} min  •  ${exercise.intensity}', style: const TextStyle(color: kTextDim, fontSize: 12)),
          ])),
          _Badge('${exercise.caloriesBurned.toStringAsFixed(0)} kcal', kOrange),
        ]),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────
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

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DetailChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: kTextDim, fontSize: 11)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14, shadows: textGlow(color))),
  ]);
}
