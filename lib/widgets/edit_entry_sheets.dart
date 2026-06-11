import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/index.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Opens a modal sheet to edit [meal]. Resolves to the edited [Meal]
/// (same id/timestamp/portion) or null if the user cancels.
Future<Meal?> showEditMealSheet(BuildContext context, Meal meal) {
  return showModalBottomSheet<Meal>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _MealEditForm(meal: meal),
    ),
  );
}

/// Opens a modal sheet to edit [exercise]. Resolves to the edited [Exercise]
/// or null if the user cancels.
Future<Exercise?> showEditExerciseSheet(BuildContext context, Exercise exercise) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _ExerciseEditForm(exercise: exercise),
    ),
  );
}

class _MealEditForm extends StatefulWidget {
  final Meal meal;
  const _MealEditForm({required this.meal});

  @override
  State<_MealEditForm> createState() => _MealEditFormState();
}

class _MealEditFormState extends State<_MealEditForm> {
  late final TextEditingController _name;
  late final TextEditingController _cal;
  late final TextEditingController _pro;
  late final TextEditingController _carb;
  late final TextEditingController _fat;

  @override
  void initState() {
    super.initState();
    final n = widget.meal.nutrients;
    _name = TextEditingController(text: widget.meal.name);
    _cal = TextEditingController(text: n.calories.toStringAsFixed(0));
    _pro = TextEditingController(text: n.protein.toStringAsFixed(1));
    _carb = TextEditingController(text: n.carbohydrates.toStringAsFixed(1));
    _fat = TextEditingController(text: n.fat.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _name.dispose();
    _cal.dispose();
    _pro.dispose();
    _carb.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    final old = widget.meal.nutrients;
    final updated = Meal(
      id: widget.meal.id,
      name: name,
      portionGrams: widget.meal.portionGrams,
      timestamp: widget.meal.timestamp,
      notes: widget.meal.notes,
      nutrients: NutrientInfo(
        calories: double.tryParse(_cal.text) ?? old.calories,
        protein: double.tryParse(_pro.text) ?? old.protein,
        carbohydrates: double.tryParse(_carb.text) ?? old.carbohydrates,
        fat: double.tryParse(_fat.text) ?? old.fat,
        fiber: old.fiber,
        sugar: old.sugar,
        minerals: old.minerals,
      ),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.s20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EDIT MEAL', style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text(widget.meal.name,
            style: AppText.titleM, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: Spacing.s16),
        _field(_name, 'Name'),
        const SizedBox(height: Spacing.s12),
        Row(children: [
          Expanded(child: _field(_cal, 'Calories', number: true)),
          const SizedBox(width: Spacing.s8),
          Expanded(child: _field(_pro, 'Protein g', number: true)),
        ]),
        const SizedBox(height: Spacing.s12),
        Row(children: [
          Expanded(child: _field(_carb, 'Carbs g', number: true)),
          const SizedBox(width: Spacing.s8),
          Expanded(child: _field(_fat, 'Fat g', number: true)),
        ]),
        const SizedBox(height: Spacing.s20),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(LucideIcons.check, size: 18),
          label: const Text('SAVE CHANGES'),
        )),
      ]),
    );
  }
}

class _ExerciseEditForm extends StatefulWidget {
  final Exercise exercise;
  const _ExerciseEditForm({required this.exercise});

  @override
  State<_ExerciseEditForm> createState() => _ExerciseEditFormState();
}

class _ExerciseEditFormState extends State<_ExerciseEditForm> {
  late final TextEditingController _name;
  late final TextEditingController _duration;
  late final TextEditingController _burned;
  late String _intensity;

  static const _intensities = ['low', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.exercise.name);
    _duration = TextEditingController(text: '${widget.exercise.durationMinutes}');
    _burned = TextEditingController(text: widget.exercise.caloriesBurned.toStringAsFixed(0));
    _intensity = _intensities.contains(widget.exercise.intensity)
        ? widget.exercise.intensity
        : 'medium';
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _burned.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    final updated = Exercise(
      id: widget.exercise.id,
      name: name,
      durationMinutes: int.tryParse(_duration.text) ?? widget.exercise.durationMinutes,
      caloriesBurned: double.tryParse(_burned.text) ?? widget.exercise.caloriesBurned,
      timestamp: widget.exercise.timestamp,
      notes: widget.exercise.notes,
      intensity: _intensity,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.s20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EDIT EXERCISE', style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text(widget.exercise.name,
            style: AppText.titleM, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: Spacing.s16),
        _field(_name, 'Name'),
        const SizedBox(height: Spacing.s12),
        Row(children: [
          Expanded(child: _field(_duration, 'Duration min', number: true)),
          const SizedBox(width: Spacing.s8),
          Expanded(child: _field(_burned, 'Burned kcal', number: true)),
        ]),
        const SizedBox(height: Spacing.s12),
        DropdownButtonFormField<String>(
          initialValue: _intensity,
          dropdownColor: AppColors.surface3,
          style: AppText.bodyM,
          decoration: const InputDecoration(labelText: 'Intensity', isDense: true),
          items: _intensities
              .map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase())))
              .toList(),
          onChanged: (v) => setState(() => _intensity = v ?? _intensity),
        ),
        const SizedBox(height: Spacing.s20),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(LucideIcons.check, size: 18),
          label: const Text('SAVE CHANGES'),
        )),
      ]),
    );
  }
}

// Shared field helper (top-level so both forms can use it). Visuals come from
// the app-level InputDecorationTheme (surface1 fill, healthRed focus border).
Widget _field(TextEditingController c, String label, {bool number = false}) {
  return TextField(
    controller: c,
    style: number ? AppText.tabular(AppText.bodyM) : AppText.bodyM,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: number
        ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
        : null,
    decoration: InputDecoration(labelText: label, isDense: true),
  );
}
