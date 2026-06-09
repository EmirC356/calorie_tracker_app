import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/index.dart';
import '../theme/app_theme.dart';

/// Opens a modal sheet to edit [meal]. Resolves to the edited [Meal]
/// (same id/timestamp/portion) or null if the user cancels.
Future<Meal?> showEditMealSheet(BuildContext context, Meal meal) {
  return showModalBottomSheet<Meal>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: kCyan, width: 1),
    ),
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
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: kPink, width: 1),
    ),
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
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EDIT MEAL', style: neonLabel(kCyan, size: 15)),
        const SizedBox(height: 14),
        _field(_name, 'Name', kCyan),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_cal, 'Calories', kCyan, number: true)),
          const SizedBox(width: 8),
          Expanded(child: _field(_pro, 'Protein g', kNeonRed, number: true)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_carb, 'Carbs g', kNeonYellow, number: true)),
          const SizedBox(width: 8),
          Expanded(child: _field(_fat, 'Fat g', kOrange, number: true)),
        ]),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('SAVE CHANGES'),
          style: ElevatedButton.styleFrom(backgroundColor: kCyan, foregroundColor: kBg),
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
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EDIT EXERCISE', style: neonLabel(kPink, size: 15)),
        const SizedBox(height: 14),
        _field(_name, 'Name', kPink),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_duration, 'Duration min', kPink, number: true)),
          const SizedBox(width: 8),
          Expanded(child: _field(_burned, 'Burned kcal', kOrange, number: true)),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _intensity,
          dropdownColor: kCard,
          style: const TextStyle(color: kText, fontSize: 14),
          decoration: _decoration('Intensity', kNeonGreen),
          items: _intensities
              .map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase())))
              .toList(),
          onChanged: (v) => setState(() => _intensity = v ?? _intensity),
        ),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('SAVE CHANGES'),
          style: ElevatedButton.styleFrom(backgroundColor: kPink, foregroundColor: kBg),
        )),
      ]),
    );
  }
}

// Shared field helpers (top-level so both forms can use them).
InputDecoration _decoration(String label, Color accent) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kTextDim, fontSize: 13),
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accent.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accent),
      ),
      filled: true,
      fillColor: kBg,
    );

Widget _field(TextEditingController c, String label, Color accent, {bool number = false}) {
  return TextField(
    controller: c,
    style: const TextStyle(color: kText, fontSize: 14),
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: number
        ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
        : null,
    decoration: _decoration(label, accent),
  );
}
