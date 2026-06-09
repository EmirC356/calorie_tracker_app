import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../providers/meal_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_entry_sheets.dart';

class MealLogsScreen extends StatefulWidget {
  const MealLogsScreen({super.key});

  @override
  State<MealLogsScreen> createState() => _MealLogsScreenState();
}

class _MealLogsScreenState extends State<MealLogsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Meal> _meals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meals = await context.read<MealProvider>().getMealsByDate(_selectedDate);
    if (mounted) setState(() => _meals = meals);
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

  void _showDetail(Meal meal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kCyan, width: 1)),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meal.name, style: neonLabel(kCyan, size: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(DateFormat('MMM d, HH:mm').format(meal.timestamp), style: const TextStyle(color: kTextDim, fontSize: 12)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Chip('Calories', '${meal.nutrients.calories.toStringAsFixed(0)} kcal', kCyan),
            _Chip('Protein', '${meal.nutrients.protein.toStringAsFixed(1)}g', kNeonRed),
            _Chip('Carbs', '${meal.nutrients.carbohydrates.toStringAsFixed(1)}g', kNeonYellow),
            _Chip('Fat', '${meal.nutrients.fat.toStringAsFixed(1)}g', kOrange),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                final provider = context.read<MealProvider>();
                Navigator.pop(context);
                final edited = await showEditMealSheet(context, meal);
                if (edited != null) {
                  await provider.updateMeal(edited);
                  if (mounted) _load();
                }
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('EDIT'),
              style: OutlinedButton.styleFrom(foregroundColor: kCyan, side: const BorderSide(color: kCyan)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await context.read<MealProvider>().deleteMeal(meal.id!);
                _load();
              },
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
    double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;
    for (final m in _meals) {
      totalCal += m.nutrients.calories;
      totalPro += m.nutrients.protein;
      totalCarb += m.nutrients.carbohydrates;
      totalFat += m.nutrients.fat;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('MEAL LOGS')),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: kSurface,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat('MMM dd, yyyy').format(_selectedDate),
              style: neonLabel(kCyan, size: 16)),
            OutlinedButton(onPressed: _pickDate, child: const Text('Change Date')),
          ]),
        ),
        Expanded(
          child: _meals.isEmpty
            ? Center(child: Text('No meals on this date', style: Theme.of(context).textTheme.bodySmall))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _meals.length,
                itemBuilder: (_, i) {
                  final m = _meals[i];
                  return GestureDetector(
                    onTap: () => _showDetail(m),
                    onLongPress: () => _showDetail(m),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: neonBox(kCyan),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(m.name, style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          Text(DateFormat('HH:mm').format(m.timestamp), style: const TextStyle(color: kTextDim, fontSize: 11)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          _Badge('${m.nutrients.calories.toStringAsFixed(0)} kcal', kCyan),
                          const SizedBox(width: 5),
                          _Badge('P ${m.nutrients.protein.toStringAsFixed(1)}g', kNeonRed),
                          const SizedBox(width: 5),
                          _Badge('C ${m.nutrients.carbohydrates.toStringAsFixed(1)}g', kNeonYellow),
                          const SizedBox(width: 5),
                          _Badge('F ${m.nutrients.fat.toStringAsFixed(1)}g', kOrange),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
        ),
        if (_meals.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(kNeonGreen, radius: 0),
            child: Column(children: [
              Text('DAILY TOTAL', style: neonLabel(kNeonGreen, size: 13)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Chip('Calories', totalCal.toStringAsFixed(0), kCyan),
                _Chip('Protein', '${totalPro.toStringAsFixed(1)}g', kNeonRed),
                _Chip('Carbs', '${totalCarb.toStringAsFixed(1)}g', kNeonYellow),
                _Chip('Fat', '${totalFat.toStringAsFixed(1)}g', kOrange),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: kTextDim, fontSize: 10)),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, shadows: textGlow(color))),
  ]);
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}
