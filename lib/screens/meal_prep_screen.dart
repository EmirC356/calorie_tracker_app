import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/food_database.dart';
import '../models/index.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/meal_prep_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

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

  bool get _isEmpty => _proteins.isEmpty && _carbs.isEmpty && _veggies.isEmpty;

  void _savePrep() {
    HapticFeedback.lightImpact();
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
    final items = [..._proteins, ..._carbs, ..._veggies]
        .map((r) => MealPrepItem(
              foodName: r.food.name,
              category: r.category,
              grams: r.grams,
            ))
        .toList();

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
      appBar: AppBar(title: const Text('Meal Prep')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Prep name (e.g. Chicken Rice Bowl)',
              ),
            ),
            const SizedBox(height: Spacing.s16),
            _SectionBlock(
              label: 'PROTEIN',
              icon: LucideIcons.beef,
              rows: _proteins,
              foods: FoodDatabase.proteins,
              onAdd: () => _addFoodRow('protein'),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: Spacing.s12),
            _SectionBlock(
              label: 'CARBS',
              icon: LucideIcons.wheat,
              rows: _carbs,
              foods: FoodDatabase.carbs,
              onAdd: () => _addFoodRow('carb'),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: Spacing.s12),
            _SectionBlock(
              label: 'VEGGIES',
              icon: LucideIcons.salad,
              rows: _veggies,
              foods: FoodDatabase.veggies,
              onAdd: () => _addFoodRow('veggie'),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: Spacing.s12),
            _buildOilSection(),
            const SizedBox(height: Spacing.s12),
            _buildAlcoholSection(),
            const SizedBox(height: Spacing.s16),
            if (!_isEmpty) ...[
              Text('PER MEAL (÷$_mealCount)', style: AppText.caption),
              const SizedBox(height: Spacing.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Chip('CAL', perMeal.calories.toStringAsFixed(0)),
                  _Chip('P', '${perMeal.protein.toStringAsFixed(1)}g'),
                  _Chip('C', '${perMeal.carbohydrates.toStringAsFixed(1)}g'),
                  _Chip('F', '${perMeal.fat.toStringAsFixed(1)}g'),
                ],
              ),
              const SizedBox(height: Spacing.s12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Meal count', style: AppText.bodyL),
                Row(children: [
                  IconButton(
                    onPressed: _mealCount > 1
                        ? () => setState(() => _mealCount--)
                        : null,
                    icon: const Icon(LucideIcons.minusCircle,
                        color: AppColors.textSecondary),
                  ),
                  Text('$_mealCount',
                      style: AppText.tabular(AppText.displayM)),
                  IconButton(
                    onPressed: () => setState(() => _mealCount++),
                    icon: const Icon(LucideIcons.plusCircle,
                        color: AppColors.textSecondary),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: Spacing.s16),
            OutlinedButton(
              onPressed: _savePrep,
              child: const Text('Save meal prep'),
            ),
            const SizedBox(height: Spacing.s32),
            const Divider(color: AppColors.surface2),
            const SizedBox(height: Spacing.s12),
            Text('SAVED MEAL PREPS', style: AppText.caption),
            const SizedBox(height: Spacing.s12),
            Consumer<MealPrepProvider>(
              builder: (_, provider, __) {
                if (provider.preps.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.s24),
                      child: Text('No meal preps yet',
                          style: AppText.bodyM
                              .copyWith(color: AppColors.textTertiary)),
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: provider.preps.length,
                  itemBuilder: (_, i) => _PrepCard(prep: provider.preps[i]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOilSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(LucideIcons.droplet,
            color: AppColors.textSecondary, size: 16),
        const SizedBox(width: Spacing.s8),
        Text('OLIVE OIL SPRAY', style: AppText.caption),
      ]),
      const SizedBox(height: Spacing.s12),
      Row(
        children: [3, 5, 10, 20].map((s) {
          final sel = _oilSprays == s;
          // Expanded so the four chips share the width and never overflow.
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.s4 / 2),
              child: GestureDetector(
                onTap: () => setState(() => _oilSprays = sel ? null : s),
                child: AnimatedContainer(
                  duration: AppMotion.enter,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(vertical: Spacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color:
                          sel ? AppColors.healthRed : AppColors.surface2,
                      width: sel ? AppMotion.focusBorderWidth : 1,
                    ),
                    boxShadow: sel
                        ? AppMotion.accentGlow(AppColors.healthRed)
                        : null,
                  ),
                  child: Text('$s sprays',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.tabular(AppText.bodyS.copyWith(
                          color: sel
                              ? AppColors.healthRed
                              : AppColors.textSecondary))),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildAlcoholSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(LucideIcons.wine, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: Spacing.s8),
        Text('ALCOHOL', style: AppText.caption),
      ]),
      const SizedBox(height: Spacing.s12),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _alcoholType,
            isExpanded: true,
            dropdownColor: AppColors.surface3,
            style: AppText.bodyS,
            hint: Text('Select drink',
                style: AppText.bodyS.copyWith(color: AppColors.textTertiary)),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: Spacing.s12, vertical: Spacing.s8),
            ),
            items: FoodDatabase.alcoholOptions
                .map((a) => DropdownMenuItem(
                    value: a.name,
                    child: Text(a.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() {
              _alcoholType = v;
              if (_alcoholQty == 0) _alcoholQty = 1;
            }),
          ),
        ),
        const SizedBox(width: Spacing.s8),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            onPressed:
                _alcoholQty > 0 ? () => setState(() => _alcoholQty--) : null,
            icon: const Icon(LucideIcons.minusCircle,
                size: 22, color: AppColors.textSecondary),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            width: 28,
            child: Text('$_alcoholQty',
                textAlign: TextAlign.center,
                style: AppText.tabular(AppText.titleM)),
          ),
          IconButton(
            onPressed: () => setState(() => _alcoholQty++),
            icon: const Icon(LucideIcons.plusCircle,
                size: 22, color: AppColors.textSecondary),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ]),
      ]),
    ]);
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
      onDismissed: (_) => context.read<MealPrepProvider>().deletePrep(prep.id!),
      child: Container(
        padding: const EdgeInsets.all(Spacing.s12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(prep.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleM.copyWith(
                    color: isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary)),
            const SizedBox(height: Spacing.s8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Spacing.s4,
              runSpacing: Spacing.s4,
              children: List.generate(total, (i) {
                final filled = i < remaining;
                return Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.healthRed : AppColors.surface2,
                  ),
                );
              }),
            ),
            const SizedBox(height: Spacing.s8),
            Text('$remaining/$total left',
                style: AppText.tabular(AppText.bodyS.copyWith(
                    color: isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textSecondary))),
            Text('${prep.perMealNutrients.calories.toStringAsFixed(0)} kcal',
                style: AppText.tabular(AppText.caption)),
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<_FoodRow> rows;
  final List<FoodItem> foods;
  final VoidCallback onAdd;
  final VoidCallback onChanged;

  const _SectionBlock({
    required this.label,
    required this.icon,
    required this.rows,
    required this.foods,
    required this.onAdd,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: Spacing.s8),
        Text(label, style: AppText.caption),
      ]),
      const SizedBox(height: Spacing.s8),
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
        icon: const Icon(LucideIcons.plus,
            size: 16, color: AppColors.healthRed),
        label: Text('Add ${label.toLowerCase()}',
            style: AppText.bodyS.copyWith(color: AppColors.healthRed)),
      ),
    ]);
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
      padding: const EdgeInsets.only(bottom: Spacing.s8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<FoodItem>(
            initialValue: widget.row.food,
            isExpanded: true,
            dropdownColor: AppColors.surface3,
            style: AppText.bodyS,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: Spacing.s12, vertical: Spacing.s8),
            ),
            items: widget.foods
                .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (f) {
              if (f != null) {
                setState(() => widget.row.food = f);
                widget.onChanged();
              }
            },
          ),
        ),
        const SizedBox(width: Spacing.s8),
        SizedBox(
          width: 70,
          child: TextField(
            controller: _gramCtrl,
            keyboardType: TextInputType.number,
            style: AppText.tabular(AppText.bodyS),
            decoration: const InputDecoration(
              suffixText: 'g',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: Spacing.s8, vertical: Spacing.s8),
            ),
            onChanged: (v) {
              widget.row.grams = double.tryParse(v) ?? widget.row.grams;
              widget.onChanged();
            },
          ),
        ),
        IconButton(
          onPressed: widget.onRemove,
          icon: const Icon(LucideIcons.x,
              color: AppColors.textTertiary, size: 18),
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
      Text(label, style: AppText.caption),
      const SizedBox(height: Spacing.s4),
      Text(value, style: AppText.tabular(AppText.titleM)),
    ]);
  }
}
