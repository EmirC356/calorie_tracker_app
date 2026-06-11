import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/food_database.dart';
import '../models/index.dart';
import '../providers/meal_provider.dart';
import '../providers/meal_prep_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ai/blocked_ai_overlay.dart';
import '../widgets/ui/shimmer_placeholder.dart';

class _FoodRow {
  FoodItem food;
  double grams;
  final String category;
  _FoodRow({required this.food, required this.grams, required this.category});

  NutrientInfo get nutrients => NutrientInfo(
        calories: food.calories * grams / 100,
        protein: food.protein * grams / 100,
        carbohydrates: food.carbs * grams / 100,
        fat: food.fat * grams / 100,
        fiber: food.fiber * grams / 100,
        sugar: 0,
      );
}

class LogMealScreen extends StatefulWidget {
  const LogMealScreen({super.key});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  // QUICK = type a brief description, Gemini estimates. DETAILED = log grams.
  bool _quickMode = true;

  // Quick mode
  final _quickCtrl = TextEditingController();
  bool _quickLoading = false;
  NutrientInfo? _quickResult;

  // Detailed mode
  final List<_FoodRow> _proteins = [];
  final List<_FoodRow> _carbs = [];
  final List<_FoodRow> _veggies = [];
  int? _oilSprays;
  String? _alcoholType;
  int _alcoholQty = 0;
  MealPrep? _pendingPrep;

  @override
  void dispose() {
    _quickCtrl.dispose();
    super.dispose();
  }

  NutrientInfo get _detailedTotals {
    double cal = 0, pro = 0, carb = 0, fat = 0, fiber = 0;
    for (final r in [..._proteins, ..._carbs, ..._veggies]) {
      cal += r.nutrients.calories;
      pro += r.nutrients.protein;
      carb += r.nutrients.carbohydrates;
      fat += r.nutrients.fat;
      fiber += r.nutrients.fiber;
    }
    if (_oilSprays != null) {
      final oil = FoodDatabase.oilSprays[_oilSprays!]!;
      cal += oil.calories;
      fat += oil.fat;
    }
    if (_alcoholType != null && _alcoholQty > 0) {
      final alc = FoodDatabase.alcoholOptions.firstWhere((a) => a.name == _alcoholType);
      cal += alc.calories * _alcoholQty;
      carb += alc.carbs * _alcoholQty;
    }
    return NutrientInfo(calories: cal, protein: pro, carbohydrates: carb, fat: fat, fiber: fiber, sugar: 0);
  }

  NutrientInfo get _totals {
    if (_quickMode) {
      return _quickResult ??
          NutrientInfo(calories: 0, protein: 0, carbohydrates: 0, fat: 0, fiber: 0, sugar: 0);
    }
    return _detailedTotals;
  }

  bool get _detailedEmpty =>
      _proteins.isEmpty && _carbs.isEmpty && _veggies.isEmpty &&
      _oilSprays == null && (_alcoholType == null || _alcoholQty == 0);

  List<_FoodRow> _listFor(String cat) {
    if (cat == 'protein') return _proteins;
    if (cat == 'carb') return _carbs;
    return _veggies;
  }

  List<FoodItem> _foodsFor(String cat) {
    if (cat == 'protein') return FoodDatabase.proteins;
    if (cat == 'carb') return FoodDatabase.carbs;
    return FoodDatabase.veggies;
  }

  void _addRow(String cat) {
    setState(() {
      _listFor(cat).add(_FoodRow(food: _foodsFor(cat).first, grams: 100, category: cat));
    });
  }

  Future<void> _estimateQuick() async {
    final text = _quickCtrl.text.trim();
    if (text.isEmpty) return;
    if (!aiService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set your Gemini key in Settings first')));
      return;
    }
    setState(() => _quickLoading = true);
    try {
      final nutrients = await aiService.analyzeFoodText(text);
      if (!mounted) return;
      setState(() => _quickResult = nutrients);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI error: $e')));
      }
    } finally {
      if (mounted) setState(() => _quickLoading = false);
    }
  }

  Future<void> _showLoadPrepDialog() async {
    final prepProvider = context.read<MealPrepProvider>();
    await prepProvider.loadPreps();
    if (!mounted) return;
    final available = prepProvider.preps.where((p) => p.remainingCount > 0).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No meal preps available')));
      return;
    }
    final chosen = await showModalBottomSheet<MealPrep>(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(Spacing.s16),
        children: [
          Text('Select Meal Prep', style: AppText.titleM),
          const SizedBox(height: Spacing.s12),
          ...available.map((p) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.name, style: AppText.bodyL),
            subtitle: Text(
              '${p.remainingCount}/${p.totalMealCount} left  •  ${p.perMealNutrients.calories.toStringAsFixed(0)} kcal per meal',
              style: AppText.tabular(
                  AppText.bodyM.copyWith(color: AppColors.textSecondary))),
            trailing: const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textTertiary),
            onTap: () => Navigator.pop(context, p),
          )),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    _loadFromPrep(chosen);
  }

  void _loadFromPrep(MealPrep prep) {
    setState(() {
      _quickMode = false; // meal preps populate the detailed breakdown
      _proteins.clear();
      _carbs.clear();
      _veggies.clear();
      _oilSprays = prep.oilSprays;
      _alcoholType = prep.alcoholType;
      _alcoholQty = prep.alcoholQuantity > 0
          ? (prep.alcoholQuantity / prep.totalMealCount).round()
          : 0;
      for (final item in prep.items) {
        final food = FoodDatabase.findByName(item.foodName);
        if (food == null) continue;
        // Divide by meal count to get per-meal portion
        final perMealGrams = item.grams / prep.totalMealCount;
        _listFor(item.category).add(_FoodRow(food: food, grams: perMealGrams, category: item.category));
      }
    });
    _pendingPrep = prep;
  }

  void _logMeal() {
    HapticFeedback.lightImpact();
    final String name;
    final NutrientInfo nutrients;

    if (_quickMode) {
      if (_quickResult == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estimate your meal with AI first')));
        return;
      }
      name = _quickCtrl.text.trim();
      nutrients = _quickResult!;
    } else {
      if (_detailedEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one food item')));
        return;
      }
      nutrients = _detailedTotals;
      final parts = [
        ..._proteins.map((r) => '${r.food.name} ${r.grams.toStringAsFixed(0)}g'),
        ..._carbs.map((r) => '${r.food.name} ${r.grams.toStringAsFixed(0)}g'),
        ..._veggies.map((r) => '${r.food.name} ${r.grams.toStringAsFixed(0)}g'),
        if (_oilSprays != null) 'Oil $_oilSprays sprays',
        if (_alcoholType != null && _alcoholQty > 0) '$_alcoholQty× $_alcoholType',
      ];
      name = parts.join(' + ');
    }

    if (nutrients.calories > kMaxSingleEntryCalories) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'That\'s ${nutrients.calories.toStringAsFixed(0)} kcal for one meal — '
              'over the ${kMaxSingleEntryCalories.toStringAsFixed(0)} kcal cap. Split it into multiple entries.')));
      return;
    }
    if (nutrients.protein > kMaxSingleMealProtein) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'That\'s ${nutrients.protein.toStringAsFixed(0)} g protein for one meal — '
              'over the ${kMaxSingleMealProtein.toStringAsFixed(0)} g cap. Split it into multiple entries.')));
      return;
    }

    context.read<MealProvider>().addMeal(Meal(
      name: name,
      portionGrams: 0,
      nutrients: nutrients,
      timestamp: DateTime.now(),
    ));
    if (_pendingPrep != null) {
      context.read<MealPrepProvider>().consumeOne(_pendingPrep!);
      _pendingPrep = null;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meal logged!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    return Scaffold(
      appBar: AppBar(title: const Text('Log Meal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Load prep button — available in both modes
          OutlinedButton.icon(
            onPressed: _showLoadPrepDialog,
            icon: const Icon(LucideIcons.package, size: 18),
            label: const Text('Load from meal prep'),
          ),
          const SizedBox(height: Spacing.s16),
          _buildModeToggle(),
          const SizedBox(height: Spacing.s16),
          if (_quickMode)
            BlockedAiOverlay(
              isBlocked: !context.watch<AiService>().hasValidKey,
              message: 'Add your API key to use AI meal estimates. '
                  'Switch to DETAILED to log exact grams without AI.',
              child: _buildQuickMode(),
            )
          else
            _buildDetailedMode(),
          const SizedBox(height: Spacing.s16),
          _buildTotals(totals),
          const SizedBox(height: Spacing.s16),
          OutlinedButton(
            onPressed: _logMeal,
            child: const Text('Log meal'),
          ),
        ]),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Row(children: [
      _modeTab('QUICK', LucideIcons.sparkles, true),
      const SizedBox(width: Spacing.s8),
      _modeTab('DETAILED', LucideIcons.slidersHorizontal, false),
    ]);
  }

  Widget _modeTab(String label, IconData icon, bool quick) {
    final selected = _quickMode == quick;
    final color =
        selected ? AppColors.healthRed : AppColors.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _quickMode = quick),
        child: AnimatedContainer(
          duration: AppMotion.enter,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(
              color: selected ? AppColors.healthRed : AppColors.surface2,
              width: selected ? AppMotion.focusBorderWidth : 1,
            ),
            boxShadow:
                selected ? AppMotion.accentGlow(AppColors.healthRed) : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: Spacing.s4),
            Text(label, style: AppText.bodyS.copyWith(color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _buildQuickMode() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DESCRIBE YOUR MEAL', style: AppText.caption),
      const SizedBox(height: Spacing.s4),
      Text('AI gives a fast estimate. Use DETAILED for exact grams.',
          style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: Spacing.s8),
      TextField(
        controller: _quickCtrl,
        maxLines: 3,
        // Editing invalidates a previous estimate so we never log stale numbers.
        onChanged: (_) { if (_quickResult != null) setState(() => _quickResult = null); },
        decoration: const InputDecoration(
          hintText: 'e.g. chicken shawarma wrap with garlic sauce and a side of fries',
        ),
      ),
      const SizedBox(height: Spacing.s12),
      OutlinedButton.icon(
        onPressed: _quickLoading ? null : _estimateQuick,
        icon: _quickLoading
            ? const ShimmerPlaceholder.line(width: 16)
            : const Icon(LucideIcons.zap, size: 18),
        label: Text(_quickLoading ? 'Estimating…' : 'Estimate with AI'),
      ),
      if (_quickLoading) ...[
        const SizedBox(height: Spacing.s12),
        const ShimmerPlaceholder.card(height: 72),
      ],
      if (_quickResult != null) ...[
        const SizedBox(height: Spacing.s12),
        Row(children: [
          const Icon(LucideIcons.checkCircle2,
              color: AppColors.statusHit, size: 16),
          const SizedBox(width: Spacing.s8),
          Expanded(
              child: Text('AI estimate ready — tap LOG MEAL to save',
                  style: AppText.bodyS
                      .copyWith(color: AppColors.textSecondary))),
        ]),
      ],
    ]);
  }

  Widget _buildDetailedMode() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildSection('PROTEIN', LucideIcons.beef, 'protein', _proteins),
      const SizedBox(height: Spacing.s12),
      _buildSection('CARBS', LucideIcons.wheat, 'carb', _carbs),
      const SizedBox(height: Spacing.s12),
      _buildSection('VEGGIES', LucideIcons.salad, 'veggie', _veggies),
      const SizedBox(height: Spacing.s12),
      _buildOilSection(),
      const SizedBox(height: Spacing.s12),
      _buildAlcoholSection(),
    ]);
  }

  Widget _buildSection(String label, IconData icon, String cat, List<_FoodRow> rows) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: Spacing.s8),
        Text(label, style: AppText.caption),
      ]),
      const SizedBox(height: Spacing.s8),
      ...rows.asMap().entries.map((e) => _FoodRowWidget(
        row: e.value,
        foods: _foodsFor(cat),
        onRemove: () { rows.removeAt(e.key); setState(() {}); },
        onChanged: () => setState(() {}),
      )),
      TextButton.icon(
        onPressed: () => _addRow(cat),
        icon: const Icon(LucideIcons.plus, size: 16, color: AppColors.healthRed),
        label: Text('Add ${label.toLowerCase()}',
            style: AppText.bodyS.copyWith(color: AppColors.healthRed)),
        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    ]);
  }

  Widget _buildOilSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(LucideIcons.droplet, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: Spacing.s8),
        Text('OLIVE OIL SPRAY', style: AppText.caption),
      ]),
      const SizedBox(height: Spacing.s8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [3, 5, 10, 20].map((s) {
          final sel = _oilSprays == s;
          return GestureDetector(
            onTap: () => setState(() => _oilSprays = sel ? null : s),
            child: AnimatedContainer(
              duration: AppMotion.enter,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.s16, vertical: Spacing.s8),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: sel ? AppColors.healthRed : AppColors.surface2,
                  width: sel ? AppMotion.focusBorderWidth : 1,
                ),
                boxShadow:
                    sel ? AppMotion.accentGlow(AppColors.healthRed) : null,
              ),
              child: Text('$s×',
                  style: AppText.tabular(AppText.bodyS.copyWith(
                      color: sel
                          ? AppColors.healthRed
                          : AppColors.textSecondary))),
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
      const SizedBox(height: Spacing.s8),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _alcoholType,
            isExpanded: true,
            dropdownColor: AppColors.surface3,
            style: AppText.bodyS,
            hint: Text('Select drink',
                style:
                    AppText.bodyS.copyWith(color: AppColors.textTertiary)),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: Spacing.s12, vertical: Spacing.s8),
            ),
            items: FoodDatabase.alcoholOptions
                .map((a) => DropdownMenuItem(value: a.name, child: Text(a.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() { _alcoholType = v; if (_alcoholQty == 0) _alcoholQty = 1; }),
          ),
        ),
        const SizedBox(width: Spacing.s8),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            onPressed: _alcoholQty > 0 ? () => setState(() => _alcoholQty--) : null,
            icon: const Icon(LucideIcons.minusCircle,
                size: 22, color: AppColors.textSecondary),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
              width: 28,
              child: Text('$_alcoholQty',
                  textAlign: TextAlign.center,
                  style: AppText.tabular(AppText.titleM))),
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

  Widget _buildTotals(NutrientInfo t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TOTALS', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Expanded(child: _Chip('CAL', t.calories.toStringAsFixed(0))),
        Expanded(child: _Chip('PRO', '${t.protein.toStringAsFixed(1)}g')),
        Expanded(child: _Chip('CARB', '${t.carbohydrates.toStringAsFixed(1)}g')),
        Expanded(child: _Chip('FAT', '${t.fat.toStringAsFixed(1)}g')),
      ]),
    ]);
  }
}

class _FoodRowWidget extends StatefulWidget {
  final _FoodRow row;
  final List<FoodItem> foods;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _FoodRowWidget({required this.row, required this.foods, required this.onRemove, required this.onChanged});

  @override
  State<_FoodRowWidget> createState() => _FoodRowWidgetState();
}

class _FoodRowWidgetState extends State<_FoodRowWidget> {
  late TextEditingController _gramCtrl;

  @override
  void initState() {
    super.initState();
    _gramCtrl = TextEditingController(text: widget.row.grams.toStringAsFixed(0));
  }

  @override
  void dispose() { _gramCtrl.dispose(); super.dispose(); }

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
                  horizontal: Spacing.s8, vertical: Spacing.s8),
            ),
            items: widget.foods.map((f) => DropdownMenuItem(value: f, child: Text(f.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (f) { if (f != null) { setState(() => widget.row.food = f); widget.onChanged(); } },
          ),
        ),
        const SizedBox(width: Spacing.s8),
        SizedBox(
          width: 68,
          child: TextField(
            controller: _gramCtrl,
            keyboardType: TextInputType.number,
            style: AppText.tabular(AppText.bodyS),
            decoration: InputDecoration(
              suffixText: 'g',
              suffixStyle:
                  AppText.bodyS.copyWith(color: AppColors.textTertiary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.s8, vertical: Spacing.s8),
            ),
            onChanged: (v) { widget.row.grams = double.tryParse(v) ?? widget.row.grams; widget.onChanged(); },
          ),
        ),
        IconButton(
          onPressed: widget.onRemove,
          icon: const Icon(LucideIcons.x,
              color: AppColors.textTertiary, size: 18),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: AppText.caption),
    const SizedBox(height: Spacing.s4),
    Text(value, style: AppText.tabular(AppText.titleM)),
  ]);
}
