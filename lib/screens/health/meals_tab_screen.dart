import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/meal_provider.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edit_entry_sheets.dart';
import '../../widgets/undo_delete.dart';
import '../../widgets/water_card.dart';
import '../log_meal_screen.dart';
import 'health_chips.dart';

/// Meals sub-tab of the Health shell — today's meals list with a log FAB.
class MealsTabScreen extends StatelessWidget {
  const MealsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MEALS TODAY')),
      body: Consumer<MealProvider>(
        builder: (_, mp, __) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WaterCard(),
            const SizedBox(height: 16),
            if (mp.todaysMeals.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No meals logged today', style: Theme.of(context).textTheme.bodySmall),
              ))
            else
              ...mp.todaysMeals.map((meal) => _MealCard(
                    meal: meal,
                    onDelete: () => deleteMealWithUndo(ScaffoldMessenger.of(context), mp, meal),
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
            DetailChip('Calories', '${meal.nutrients.calories.toStringAsFixed(0)} kcal', kCyan),
            DetailChip('Protein', '${meal.nutrients.protein.toStringAsFixed(1)}g', kNeonRed),
            DetailChip('Carbs', '${meal.nutrients.carbohydrates.toStringAsFixed(1)}g', kNeonYellow),
            DetailChip('Fat', '${meal.nutrients.fat.toStringAsFixed(1)}g', kOrange),
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
            StatBadge('${meal.nutrients.calories.toStringAsFixed(0)} kcal', kCyan),
            const SizedBox(width: 6),
            StatBadge('P ${meal.nutrients.protein.toStringAsFixed(1)}g', kNeonRed),
            const SizedBox(width: 6),
            StatBadge('C ${meal.nutrients.carbohydrates.toStringAsFixed(1)}g', kNeonYellow),
            const Spacer(),
            Text(DateFormat('HH:mm').format(meal.timestamp), style: const TextStyle(color: kTextDim, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}
