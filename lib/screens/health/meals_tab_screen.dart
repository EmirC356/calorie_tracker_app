import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/index.dart';
import '../../providers/meal_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/date_nav_bar.dart';
import '../../widgets/edit_entry_sheets.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/undo_delete.dart';
import '../../widgets/water_card.dart';
import '../log_meal_screen.dart';
import 'health_chips.dart';

/// Meals sub-tab of the Health shell — the selected day's meals as a timeline
/// (entries breathe directly on surface0; no card chrome) with a date
/// navigator to browse previous days. The FAB always logs to today.
class MealsTabScreen extends StatefulWidget {
  const MealsTabScreen({super.key});

  @override
  State<MealsTabScreen> createState() => _MealsTabScreenState();
}

class _MealsTabScreenState extends State<MealsTabScreen> {
  late final MealProvider _provider;
  DateTime _date = dateOnly(DateTime.now());
  List<Meal> _meals = [];

  bool get _isToday => _date == dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _provider = context.read<MealProvider>();
    _provider.addListener(_reload); // refresh after add/edit/delete/undo
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _provider.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final meals = await _provider.getMealsByDate(_date);
    if (mounted) setState(() => _meals = meals);
  }

  void _setDate(DateTime d) {
    setState(() => _date = d);
    _reload();
  }

  Future<void> _logMeal() async {
    await Navigator.push(
        context, HeroTransitionScaffold.route(const LogMealScreen()));
    if (mounted) _setDate(dateOnly(DateTime.now())); // logging targets today
  }

  @override
  Widget build(BuildContext context) {
    final accent = SectionAccent.of(context);
    return Scaffold(
      appBar: SectionAppBar(title: 'Meals', accent: accent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DateNavBar(selected: _date, accent: accent, onChanged: _setDate),
          const SizedBox(height: Spacing.s12),
          if (_meals.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(Spacing.s48),
              child: Text(
                  _isToday
                      ? 'No meals logged today'
                      : 'No meals logged on this day',
                  style:
                      AppText.bodyM.copyWith(color: AppColors.textTertiary)),
            ))
          else
            // Timeline: a 2px surface2 line down the left edge; entries sit
            // directly on surface0.
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    left: BorderSide(color: AppColors.surface2, width: 2)),
              ),
              padding: const EdgeInsets.only(left: Spacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final meal in _meals)
                    _MealTimelineEntry(
                      meal: meal,
                      onDelete: () => deleteMealWithUndo(
                          ScaffoldMessenger.of(context), _provider, meal),
                      onEdit: (updated) => _provider.updateMeal(updated),
                    ),
                ],
              ),
            ),
          // Water quick-add sits at the bottom (today only).
          if (_isToday) ...[
            const SizedBox(height: Spacing.s20),
            const WaterCard(),
          ],
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logMeal,
        backgroundColor: accent,
        foregroundColor: AppColors.surface0,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }
}

class _MealTimelineEntry extends StatelessWidget {
  final Meal meal;
  final VoidCallback onDelete;
  final ValueChanged<Meal> onEdit;
  const _MealTimelineEntry(
      {required this.meal, required this.onDelete, required this.onEdit});

  void _showDetail(BuildContext context) {
    final accent = SectionAccent.of(context);
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(Spacing.s20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meal.name,
              style: AppText.titleM, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: Spacing.s4),
          Text(
              DateFormat('MMM d, HH:mm').format(meal.timestamp).toUpperCase(),
              style: AppText.tabular(AppText.caption)),
          const SizedBox(height: Spacing.s16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            DetailChip('Calories',
                meal.nutrients.calories.toStringAsFixed(0), accent),
            DetailChip('Protein',
                '${meal.nutrients.protein.toStringAsFixed(1)}g', accent),
            DetailChip('Carbs',
                '${meal.nutrients.carbohydrates.toStringAsFixed(1)}g', accent),
            DetailChip(
                'Fat', '${meal.nutrients.fat.toStringAsFixed(1)}g', accent),
          ]),
          const SizedBox(height: Spacing.s20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final edited = await showEditMealSheet(context, meal);
                if (edited != null) onEdit(edited);
              },
              icon: const Icon(LucideIcons.pencil, size: 16),
              label: const Text('EDIT'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(
                      color: accent, width: AppMotion.focusBorderWidth)),
            )),
            const SizedBox(width: Spacing.s8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () { Navigator.pop(context); onDelete(); },
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('DELETE'),
              // Destructive: 1.5px statusMissed border, never a red fill.
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusMissed,
                  side: const BorderSide(
                      color: AppColors.statusMissed,
                      width: AppMotion.focusBorderWidth)),
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
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Spacing.s20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Time chip.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.s8, vertical: Spacing.s4),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(DateFormat('HH:mm').format(meal.timestamp),
                style: AppText.tabular(AppText.caption)),
          ),
          const SizedBox(height: Spacing.s8),
          Text(meal.name,
              style: AppText.titleM, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: Spacing.s4),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(meal.nutrients.calories.toStringAsFixed(0),
                    style: AppText.tabular(AppText.displayM)),
                const SizedBox(width: Spacing.s4),
                Text('kcal',
                    style:
                        AppText.bodyM.copyWith(color: AppColors.textTertiary)),
              ]),
          const SizedBox(height: Spacing.s8),
          Row(children: [
            StatBadge('P ${meal.nutrients.protein.toStringAsFixed(1)}g',
                AppColors.textSecondary),
            const SizedBox(width: Spacing.s8),
            StatBadge('C ${meal.nutrients.carbohydrates.toStringAsFixed(1)}g',
                AppColors.textSecondary),
            const SizedBox(width: Spacing.s8),
            StatBadge('F ${meal.nutrients.fat.toStringAsFixed(1)}g',
                AppColors.textSecondary),
          ]),
        ]),
      ),
    );
  }
}
