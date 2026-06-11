import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../providers/exercise_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/weight_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/dashboard_charts.dart';
import '../../widgets/ui/section_nav.dart';
import '../../widgets/ui/ui.dart';
import '../exercise_logging_screen.dart';
import '../exercise_logs_screen.dart';
import '../log_meal_screen.dart';
import '../meal_logs_screen.dart';
import '../meal_prep_screen.dart';
import '../profile_screen.dart';
import '../settings_screen.dart';

/// Dashboard sub-tab of the Health shell. Today's calories as the data-hero
/// (AnimatedRing + HeroStat), supporting stats on ColoredLeftBorderCards,
/// trend charts, and quick actions. The AppBar gear opens Settings (same as
/// before); Meal Prep moved here as an AppBar action when the bottom nav
/// collapsed to 3 tabs, and the Advisor chat icon was dropped because Advisor
/// is now its own Health sub-tab.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, HeroTransitionScaffold.route(page));

  @override
  Widget build(BuildContext context) {
    final accent = SectionAccent.of(context);
    return Scaffold(
      appBar: SectionAppBar(
        title: 'Dashboard',
        caption: 'Health',
        accent: accent,
        actions: [
          IconButton(
              icon: const Icon(LucideIcons.package, size: 20),
              tooltip: 'Meal Prep',
              onPressed: () => _push(context, const MealPrepScreen())),
          IconButton(
              icon: const Icon(LucideIcons.user, size: 20),
              tooltip: 'Profile & Goals',
              onPressed: () => _push(context, const ProfileScreen())),
          IconButton(
              icon: const Icon(LucideIcons.settings, size: 20),
              tooltip: 'Settings',
              onPressed: () => _push(context, const SettingsScreen())),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        // Staggered reveal on enter: hero ring → cards → trends → actions.
        child: AnimationLimiter(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: AnimationConfiguration.toStaggeredList(
            duration: AppMotion.enter,
            delay: AppMotion.staggerStep,
            childAnimationBuilder: (w) => SlideAnimation(
              verticalOffset: 24,
              curve: Curves.easeOutCubic,
              child: FadeInAnimation(child: w),
            ),
            children: [
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
              final ringProgress = (calTarget != null && calTarget > 0)
                  ? (cal / calTarget).clamp(0.0, 1.0)
                  : 0.0;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── The data hero: today's calories in the ring ─────────────
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.s16),
                    child: AnimatedRing(
                      progress: ringProgress,
                      accent: accent,
                      size: 264,
                      child: HeroStat(
                        value: cal,
                        target: calTarget,
                        label: 'Calories today',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.s16),
                _ProgressCard(
                  label: 'Protein',
                  consumed: pro,
                  target: proTarget,
                  unit: 'g',
                  accent: accent,
                ),
                const SizedBox(height: Spacing.s8),
                _SummaryCard(
                    label: 'Calories burned',
                    value: burned,
                    unit: 'kcal',
                    accent: accent),
                const SizedBox(height: Spacing.s8),
                _SummaryCard(
                    label: 'Net calories',
                    value: net,
                    unit: 'kcal',
                    accent: accent,
                    valueColor:
                        net > 0 ? AppColors.statusMissed : AppColors.statusHit),
                if (!hasTargets) ...[
                  const SizedBox(height: Spacing.s12),
                  GestureDetector(
                    onTap: () => _push(context, const ProfileScreen()),
                    child: Text(
                      'Set your profile to see calorie & protein targets →',
                      style: AppText.bodyS.copyWith(color: accent),
                    ),
                  ),
                ],
              ]);
            },
          ),
          const SizedBox(height: Spacing.s24),
          Text('TRENDS', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          Consumer3<MealProvider, ProfileProvider, WeightProvider>(
            builder: (_, meals, profileP, weightP, __) {
              final profile = profileP.profile;
              final weight = weightP.latest?.weight ?? profile?.fallbackWeightKg;
              final goal = (profileP.hasProfile && weight != null && weight > 0)
                  ? profile!.calorieTarget(weight)
                  : null;
              return Column(children: [
                CollapsibleChartSection(
                  title: 'CALORIES — LAST 14 DAYS',
                  accent: accent,
                  initiallyExpanded: true,
                  child: CaloriesBarChart(totals: meals.dailyCalories(14), goal: goal),
                ),
                CollapsibleChartSection(
                  title: 'WEIGHT — LAST 90 DAYS',
                  accent: accent,
                  child: WeightLineChart(entries: weightP.entries),
                ),
                CollapsibleChartSection(
                  title: "TODAY'S MACROS",
                  accent: accent,
                  child: MacrosDonut(
                    protein: meals.todaysTotalProtein,
                    carbs: meals.todaysTotalCarbs,
                    fat: meals.todaysTotalFat,
                  ),
                ),
              ]);
            },
          ),
          const SizedBox(height: Spacing.s12),
          Text('QUICK ACTIONS', style: AppText.caption),
          const SizedBox(height: Spacing.s12),
          Row(children: [
            Expanded(
                child: _actionButton(context, 'Log Meal', LucideIcons.plus,
                    () => _push(context, const LogMealScreen()), accent)),
            const SizedBox(width: Spacing.s12),
            Expanded(
                child: _actionButton(context, 'Log Exercise',
                    LucideIcons.dumbbell,
                    () => _push(context, const ExerciseLoggingScreen()),
                    accent)),
          ]),
          const SizedBox(height: Spacing.s16),
          Row(children: [
            Expanded(
                child: _actionButton(context, 'Meal Logs', LucideIcons.history,
                    () => _push(context, const MealLogsScreen()), accent)),
            const SizedBox(width: Spacing.s12),
            Expanded(
                child: _actionButton(context, 'Exercise Logs',
                    LucideIcons.history,
                    () => _push(context, const ExerciseLogsScreen()), accent)),
          ]),
            ],
          )),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, String label, IconData icon,
      VoidCallback onTap, Color accent) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent, width: AppMotion.focusBorderWidth),
        padding: const EdgeInsets.symmetric(vertical: Spacing.s12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyS),
    );
  }
}

/// Supporting stat row on a ColoredLeftBorderCard: caption label, tabular
/// displayM number, optional thin progress fill toward the target.
class _ProgressCard extends StatelessWidget {
  final String label;
  final double consumed;
  final double? target;
  final String unit;
  final Color accent;
  const _ProgressCard({
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = target != null && target! > 0;
    final ratio = hasTarget ? (consumed / target!).clamp(0.0, 1.0) : 0.0;
    final over = hasTarget && consumed > target!;
    final fillColor = over ? AppColors.statusMissed : accent;
    return ColoredLeftBorderCard(
      accent: accent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                consumed.toStringAsFixed(label == 'Protein' ? 1 : 0),
                style: AppText.tabular(AppText.displayM),
              ),
              const SizedBox(width: Spacing.s4),
              Text(
                hasTarget ? '/ ${target!.toStringAsFixed(0)} $unit' : unit,
                style: AppText.tabular(
                    AppText.bodyM.copyWith(color: AppColors.textTertiary)),
              ),
            ]),
        if (hasTarget) ...[
          const SizedBox(height: Spacing.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
          const SizedBox(height: Spacing.s4),
          Text(
            over
                ? '${(consumed - target!).toStringAsFixed(0)} $unit over target'
                : '${(target! - consumed).toStringAsFixed(0)} $unit left',
            style: AppText.tabular(
                AppText.caption.copyWith(color: AppColors.textTertiary)),
          ),
        ],
      ]),
    );
  }
}

/// Plain stat row on a ColoredLeftBorderCard: caption label + tabular number.
class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color accent;
  final Color? valueColor;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredLeftBorderCard(
      accent: accent,
      child: Row(children: [
        Expanded(child: Text(label.toUpperCase(), style: AppText.caption)),
        Text(value.toStringAsFixed(0),
            style: AppText.tabular(AppText.displayM)
                .copyWith(color: valueColor ?? AppColors.textPrimary)),
        const SizedBox(width: Spacing.s4),
        Text(unit,
            style: AppText.bodyM.copyWith(color: AppColors.textTertiary)),
      ]),
    );
  }
}
