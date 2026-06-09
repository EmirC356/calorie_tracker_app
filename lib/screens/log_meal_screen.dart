import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/food_database.dart';
import '../models/index.dart';
import '../providers/meal_provider.dart';
import '../providers/meal_prep_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

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
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kCyan, width: 1)),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Select Meal Prep', style: neonLabel(kCyan, size: 18)),
          const SizedBox(height: 12),
          ...available.map((p) => ListTile(
            title: Text(p.name, style: const TextStyle(color: kText)),
            subtitle: Text(
              '${p.remainingCount}/${p.totalMealCount} left  •  ${p.perMealNutrients.calories.toStringAsFixed(0)} kcal per meal',
              style: const TextStyle(color: kTextDim, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kCyan),
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
      appBar: AppBar(title: const Text('LOG MEAL')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Load prep button — available in both modes
          OutlinedButton.icon(
            onPressed: _showLoadPrepDialog,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('LOAD FROM MEAL PREP'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: kNeonYellow,
              side: const BorderSide(color: kNeonYellow),
            ),
          ),
          const SizedBox(height: 14),
          _buildModeToggle(),
          const SizedBox(height: 16),
          if (_quickMode) _buildQuickMode() else _buildDetailedMode(),
          const SizedBox(height: 16),
          _buildTotals(totals),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _logMeal,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: kCyan,
              foregroundColor: kBg,
              shadowColor: kCyan,
              elevation: 8,
            ),
            child: const Text('LOG MEAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        ]),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderDim),
      ),
      child: Row(children: [
        _modeTab('QUICK', Icons.auto_awesome, true),
        _modeTab('DETAILED', Icons.tune, false),
      ]),
    );
  }

  Widget _modeTab(String label, IconData icon, bool quick) {
    final selected = _quickMode == quick;
    final accent = quick ? kCyan : kNeonGreen;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _quickMode = quick),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected ? [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 8)] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: selected ? kBg : accent),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: selected ? kBg : accent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 13,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildQuickMode() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kCyan),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, color: kCyan, size: 18),
          const SizedBox(width: 8),
          Text('DESCRIBE YOUR MEAL', style: neonLabel(kCyan)),
        ]),
        const SizedBox(height: 4),
        const Text('AI gives a fast estimate. Use DETAILED for exact grams.',
          style: TextStyle(color: kTextDim, fontSize: 11)),
        const SizedBox(height: 10),
        TextField(
          controller: _quickCtrl,
          maxLines: 3,
          style: const TextStyle(color: kText, fontSize: 14),
          // Editing invalidates a previous estimate so we never log stale numbers.
          onChanged: (_) { if (_quickResult != null) setState(() => _quickResult = null); },
          decoration: InputDecoration(
            hintText: 'e.g. chicken shawarma wrap with garlic sauce and a side of fries',
            hintStyle: const TextStyle(color: kTextDim, fontSize: 13),
            filled: true,
            fillColor: kSurface,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kCyan.withOpacity(0.4))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCyan)),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _quickLoading ? null : _estimateQuick,
          style: ElevatedButton.styleFrom(
            backgroundColor: kCyan,
            foregroundColor: kBg,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shadowColor: kCyan,
            elevation: 6,
          ),
          icon: _quickLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kBg))
              : const Icon(Icons.bolt, size: 18),
          label: Text(_quickLoading ? 'ESTIMATING...' : 'ESTIMATE WITH AI',
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        if (_quickResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kCyan.withOpacity(0.5)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: kNeonGreen, size: 16),
              const SizedBox(width: 8),
              const Expanded(child: Text('AI estimate ready — tap LOG MEAL to save',
                style: TextStyle(color: kTextDim, fontSize: 12))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildDetailedMode() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildSection('PROTEIN', kNeonRed, Icons.egg_alt, 'protein', _proteins),
      const SizedBox(height: 12),
      _buildSection('CARBS', kNeonYellow, Icons.grain, 'carb', _carbs),
      const SizedBox(height: 12),
      _buildSection('VEGGIES', kNeonGreen, Icons.eco, 'veggie', _veggies),
      const SizedBox(height: 12),
      _buildOilSection(),
      const SizedBox(height: 12),
      _buildAlcoholSection(),
    ]);
  }

  Widget _buildSection(String label, Color accent, IconData icon, String cat, List<_FoodRow> rows) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: neonBox(accent),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Text(label, style: neonLabel(accent)),
        ]),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((e) => _FoodRowWidget(
          row: e.value,
          foods: _foodsFor(cat),
          onRemove: () { rows.removeAt(e.key); setState(() {}); },
          onChanged: () => setState(() {}),
          accent: accent,
        )),
        TextButton.icon(
          onPressed: () => _addRow(cat),
          icon: Icon(Icons.add, size: 16, color: accent),
          label: Text('Add $label', style: TextStyle(color: accent, fontSize: 12)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ),
      ]),
    );
  }

  Widget _buildOilSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: neonBox(kOrange),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.opacity, color: kOrange, size: 18),
          const SizedBox(width: 8),
          Text('OLIVE OIL SPRAY', style: neonLabel(kOrange)),
        ]),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [3, 5, 10, 20].map((s) {
            final sel = _oilSprays == s;
            return GestureDetector(
              onTap: () => setState(() => _oilSprays = sel ? null : s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? kOrange : kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kOrange),
                  boxShadow: sel ? [BoxShadow(color: kOrange.withOpacity(0.4), blurRadius: 8)] : null,
                ),
                child: Text('$s×', style: TextStyle(color: sel ? kBg : kOrange, fontWeight: FontWeight.bold)),
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
      decoration: neonBox(kPurple),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_bar, color: kPurple, size: 18),
          const SizedBox(width: 8),
          Text('ALCOHOL', style: neonLabel(kPurple)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _alcoholType,
              isExpanded: true,
              dropdownColor: kCard,
              style: const TextStyle(color: kText, fontSize: 13),
              hint: const Text('Select drink', style: TextStyle(color: kTextDim, fontSize: 13)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderDim)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPurple)),
                filled: true, fillColor: kSurface,
              ),
              items: FoodDatabase.alcoholOptions
                  .map((a) => DropdownMenuItem(value: a.name, child: Text(a.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() { _alcoholType = v; if (_alcoholQty == 0) _alcoholQty = 1; }),
            ),
          ),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              onPressed: _alcoholQty > 0 ? () => setState(() => _alcoholQty--) : null,
              icon: const Icon(Icons.remove_circle_outline, size: 22, color: kPurple),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
            SizedBox(width: 28, child: Text('$_alcoholQty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText))),
            IconButton(
              onPressed: () => setState(() => _alcoholQty++),
              icon: const Icon(Icons.add_circle_outline, size: 22, color: kPurple),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildTotals(NutrientInfo t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kCyan),
      child: Column(children: [
        Text('TOTALS', style: neonLabel(kCyan, size: 15)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Expanded(child: _Chip('CAL', t.calories.toStringAsFixed(0), kCyan)),
          Expanded(child: _Chip('PRO', '${t.protein.toStringAsFixed(1)}g', kNeonRed)),
          Expanded(child: _Chip('CARB', '${t.carbohydrates.toStringAsFixed(1)}g', kNeonYellow)),
          Expanded(child: _Chip('FAT', '${t.fat.toStringAsFixed(1)}g', kOrange)),
        ]),
      ]),
    );
  }
}

class _FoodRowWidget extends StatefulWidget {
  final _FoodRow row;
  final List<FoodItem> foods;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final Color accent;

  const _FoodRowWidget({required this.row, required this.foods, required this.onRemove, required this.onChanged, required this.accent});

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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<FoodItem>(
            value: widget.row.food,
            isExpanded: true,
            dropdownColor: kCard,
            style: const TextStyle(color: kText, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.accent.withOpacity(0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.accent)),
              filled: true, fillColor: kSurface,
            ),
            items: widget.foods.map((f) => DropdownMenuItem(value: f, child: Text(f.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (f) { if (f != null) { setState(() => widget.row.food = f); widget.onChanged(); } },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 68,
          child: TextField(
            controller: _gramCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: kText, fontSize: 13),
            decoration: InputDecoration(
              suffixText: 'g',
              suffixStyle: const TextStyle(color: kTextDim, fontSize: 12),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorderDim)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.accent)),
              filled: true, fillColor: kSurface,
            ),
            onChanged: (v) { widget.row.grams = double.tryParse(v) ?? widget.row.grams; widget.onChanged(); },
          ),
        ),
        IconButton(
          onPressed: widget.onRemove,
          icon: const Icon(Icons.close, color: kNeonRed, size: 18),
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
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: kTextDim)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color, shadows: textGlow(color))),
  ]);
}
