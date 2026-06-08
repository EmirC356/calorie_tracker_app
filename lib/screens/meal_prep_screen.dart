import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/food_database.dart';
import '../models/index.dart';
import '../providers/meal_prep_provider.dart';
import '../theme/app_theme.dart';

class _FoodRow {
  FoodItem food;
  double grams;
  final String category;
  _FoodRow({required this.food, required this.grams, required this.category});
}

class MealPrepScreen extends StatefulWidget {
  const MealPrepScreen({super.key});

  @override
  State<MealPrepScreen> createState() => _MealPrepScreenState();
}

class _MealPrepScreenState extends State<MealPrepScreen> {
  final _nameCtrl = TextEditingController();
  final List<_FoodRow> _proteins = [];
  final List<_FoodRow> _carbs = [];
  final List<_FoodRow> _veggies = [];
  int? _oilSprays;
  String? _alcoholType;
  int _alcoholQty = 0;
  int _mealCount = 1;

  @override
  void initState() {
    super.initState();
    context.read<MealPrepProvider>().loadPreps();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  NutrientInfo get _totalNutrients {
    double cal = 0, pro = 0, carb = 0, fat = 0, fiber = 0;
    for (final row in [..._proteins, ..._carbs, ..._veggies]) {
      cal += row.food.calories * row.grams / 100;
      pro += row.food.protein * row.grams / 100;
      carb += row.food.carbs * row.grams / 100;
      fat += row.food.fat * row.grams / 100;
      fiber += row.food.fiber * row.grams / 100;
    }
    if (_oilSprays != null) {
      final oil = FoodDatabase.oilSprays[_oilSprays!]!;
      cal += oil.calories;
      fat += oil.fat;
    }
    if (_alcoholType != null && _alcoholQty > 0) {
      final alc =
          FoodDatabase.alcoholOptions.firstWhere((a) => a.name == _alcoholType);
      cal += alc.calories * _alcoholQty;
      carb += alc.carbs * _alcoholQty;
    }
    return NutrientInfo(
        calories: cal, protein: pro, carbohydrates: carb, fat: fat, fiber: fiber, sugar: 0);
  }

  NutrientInfo _perMeal(NutrientInfo total) => NutrientInfo(
        calories: total.calories / _mealCount,
        protein: total.protein / _mealCount,
        carbohydrates: total.carbohydrates / _mealCount,
        fat: total.fat / _mealCount,
        fiber: total.fiber / _mealCount,
        sugar: 0,
      );

  void _addFoodRow(String category) {
    final foods = _foodsFor(category);
    setState(() {
      _listFor(category)
          .add(_FoodRow(food: foods.first, grams: 100, category: category));
    });
  }

  List<_FoodRow> _listFor(String category) {
    switch (category) {
      case 'protein':
        return _proteins;
      case 'carb':
        return _carbs;
      default:
        return _veggies;
    }
  }

  List<FoodItem> _foodsFor(String category) {
    switch (category) {
      case 'protein':
        return FoodDatabase.proteins;
      case 'carb':
        return FoodDatabase.carbs;
      default:
        return FoodDatabase.veggies;
    }
  }

  bool get _isEmpty =>
      _proteins.isEmpty && _carbs.isEmpty && _veggies.isEmpty;

  void _savePrep() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name for this meal prep')),
      );
      return;
    }
    if (_isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one food item')),
      );
      return;
    }

    final total = _totalNutrients;
    final perMeal = _perMeal(total);
    final items = [
      ..._proteins,
      ..._carbs,
      ..._veggies,
    ].map((r) => MealPrepItem(
          foodName: r.food.name,
          category: r.category,
          grams: r.grams,
        )).toList();

    final prep = MealPrep(
      name: _nameCtrl.text.trim(),
      items: items,
      oilSprays: _oilSprays,
      alcoholType: _alcoholType,
      alcoholQuantity: _alcoholQty,
      totalNutrients: total,
      perMealNutrients: perMeal,
      totalMealCount: _mealCount,
      remainingCount: _mealCount,
      createdAt: DateTime.now(),
    );

    context.read<MealPrepProvider>().addPrep(prep);

    // Reset form
    setState(() {
      _nameCtrl.clear();
      _proteins.clear();
      _carbs.clear();
      _veggies.clear();
      _oilSprays = null;
      _alcoholType = null;
      _alcoholQty = 0;
      _mealCount = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meal prep saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalNutrients;
    final perMeal = _perMeal(total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Prep'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prep name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Prep Name (e.g. Chicken Rice Bowl)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),

            // Protein
            _SectionBlock(
              label: 'Protein',
              icon: Icons.egg_alt,
              color: Colors.red.shade700,
              rows: _proteins,
              foods: FoodDatabase.proteins,
              onAdd: () => _addFoodRow('protein'),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Carbs
            _SectionBlock(
              label: 'Carbs',
              icon: Icons.grain,
              color: Colors.amber.shade700,
              rows: _carbs,
              foods: FoodDatabase.carbs,
              onAdd: () => _addFoodRow('carb'),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Veggies
            _SectionBlock(
              label: 'Veggies',
              icon: Icons.eco,
              color: Colors.green.shade700,
              rows: _veggies,
              foods: FoodDatabase.veggies,
              onAdd: () => _addFoodRow('veggie'),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),

            _buildOilSection(),
            const SizedBox(height: 12),
            _buildAlcoholSection(),
            const SizedBox(height: 16),

            // Totals preview
            if (!_isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(children: [
                  Text('Per meal (÷$_mealCount)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Chip('Cal', '${perMeal.calories.toStringAsFixed(0)}kcal'),
                      _Chip('P', '${perMeal.protein.toStringAsFixed(1)}g'),
                      _Chip('C', '${perMeal.carbohydrates.toStringAsFixed(1)}g'),
                      _Chip('F', '${perMeal.fat.toStringAsFixed(1)}g'),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Meal count stepper
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Meal Count',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(children: [
                    IconButton(
                      onPressed: _mealCount > 1
                          ? () => setState(() => _mealCount--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_mealCount',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => setState(() => _mealCount++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _savePrep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.teal,
              ),
              child: const Text('Save Meal Prep',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),

            // Saved preps
            const Text('Saved Meal Preps',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Consumer<MealPrepProvider>(
              builder: (_, provider, __) {
                if (provider.preps.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No meal preps yet',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: provider.preps.length,
                  itemBuilder: (_, i) =>
                      _PrepCard(prep: provider.preps[i]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOilSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.opacity, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Text('Olive Oil Spray',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
        ]),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [3, 5, 10, 20].map((s) {
            final sel = _oilSprays == s;
            return GestureDetector(
              onTap: () => setState(() => _oilSprays = sel ? null : s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? Colors.orange.shade600 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade400),
                ),
                child: Text('$s sprays',
                    style: TextStyle(
                        color: sel ? Colors.white : Colors.orange.shade800,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _buildAlcoholSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_bar, color: Colors.purple.shade700, size: 20),
          const SizedBox(width: 8),
          Text('Alcohol',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _alcoholType,
              isExpanded: true,
              hint: const Text('Select drink'),
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: FoodDatabase.alcoholOptions
                  .map((a) => DropdownMenuItem(
                      value: a.name,
                      child: Text(a.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() {
                _alcoholType = v;
                if (_alcoholQty == 0) _alcoholQty = 1;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              onPressed:
                  _alcoholQty > 0 ? () => setState(() => _alcoholQty--) : null,
              icon: const Icon(Icons.remove_circle_outline, size: 22),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
            SizedBox(
              width: 28,
              child: Text('$_alcoholQty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: () => setState(() => _alcoholQty++),
              icon: const Icon(Icons.add_circle_outline, size: 22),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ]),
        ]),
      ]),
    );
  }
}

class _PrepCard extends StatelessWidget {
  final MealPrep prep;
  const _PrepCard({required this.prep});

  @override
  Widget build(BuildContext context) {
    final remaining = prep.remainingCount;
    final total = prep.totalMealCount;
    final isEmpty = remaining == 0;

    return Dismissible(
      key: ValueKey(prep.id),
      direction: DismissDirection.vertical,
      onDismissed: (_) =>
          context.read<MealPrepProvider>().deletePrep(prep.id!),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEmpty ? Colors.grey.shade200 : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isEmpty ? Colors.grey.shade400 : Colors.teal.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(prep.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isEmpty ? Colors.grey : Colors.teal.shade800)),
            const SizedBox(height: 8),
            // Portion dots
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: List.generate(total, (i) {
                final filled = i < remaining;
                return Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Colors.teal : Colors.grey.shade300,
                    border: Border.all(
                        color: filled
                            ? Colors.teal.shade700
                            : Colors.grey.shade400),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text('$remaining/$total left',
                style: TextStyle(
                    fontSize: 12,
                    color: isEmpty ? Colors.grey : Colors.teal.shade700)),
            Text('${prep.perMealNutrients.calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// Shared section block widget (same as in log_meal_screen)
class _SectionBlock extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<_FoodRow> rows;
  final List<FoodItem> foods;
  final VoidCallback onAdd;
  final VoidCallback onChanged;

  const _SectionBlock({
    required this.label,
    required this.icon,
    required this.color,
    required this.rows,
    required this.foods,
    required this.onAdd,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Color.fromRGBO(color.red, color.green, color.blue, 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Color.fromRGBO(color.red, color.green, color.blue, 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((e) {
          final idx = e.key;
          final row = e.value;
          return _FoodRowWidget(
            row: row,
            foods: foods,
            onRemove: () {
              rows.removeAt(idx);
              onChanged();
            },
            onChanged: onChanged,
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: Text('Add $label'),
        ),
      ]),
    );
  }
}

class _FoodRowWidget extends StatefulWidget {
  final _FoodRow row;
  final List<FoodItem> foods;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _FoodRowWidget({
    required this.row,
    required this.foods,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_FoodRowWidget> createState() => _FoodRowWidgetState();
}

class _FoodRowWidgetState extends State<_FoodRowWidget> {
  late TextEditingController _gramCtrl;

  @override
  void initState() {
    super.initState();
    _gramCtrl =
        TextEditingController(text: widget.row.grams.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _gramCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<FoodItem>(
            value: widget.row.food,
            isExpanded: true,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            items: widget.foods
                .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (f) {
              if (f != null) {
                setState(() => widget.row.food = f);
                widget.onChanged();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: TextField(
            controller: _gramCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: 'g',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onChanged: (v) {
              widget.row.grams = double.tryParse(v) ?? widget.row.grams;
              widget.onChanged();
            },
          ),
        ),
        IconButton(
          onPressed: widget.onRemove,
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          padding: EdgeInsets.zero,
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
    ]);
  }
}
