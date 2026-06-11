import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/met_table.dart';
import '../models/index.dart';
import '../providers/exercise_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/weight_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ui/ui.dart';
import 'settings/api_key_screen.dart';

class ExerciseLoggingScreen extends StatefulWidget {
  const ExerciseLoggingScreen({super.key});

  @override
  State<ExerciseLoggingScreen> createState() => _ExerciseLoggingScreenState();
}

class _ExerciseLoggingScreenState extends State<ExerciseLoggingScreen> {
  static const _accent = AppColors.healthRed;

  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _notesController = TextEditingController();

  String _intensity = 'medium';
  static const _intensities = ['low', 'medium', 'high'];

  MetActivity? _selectedActivity;
  bool _autoFilled = false;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    // Ensure we have a body weight available for the MET estimate.
    final weight = context.read<WeightProvider>();
    final profile = context.read<ProfileProvider>();
    Future.microtask(() {
      weight.loadEntries();
      profile.load();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// (weightKg, sourceLabel) used for the MET estimate. Falls back to a
  /// default if the user has neither a logged weight nor a profile weight.
  (double, String) get _weightInfo {
    final logged = context.read<WeightProvider>().latest?.weight;
    if (logged != null) return (logged, 'logged weight');
    final profileWeight = context.read<ProfileProvider>().profile?.fallbackWeightKg;
    if (profileWeight != null) return (profileWeight, 'profile weight');
    return (70, 'default 70 kg — set your weight');
  }

  /// MET-based recalc for a picked activity, scaled by intensity.
  void _recalcCalories() {
    final activity = _selectedActivity;
    final minutes = int.tryParse(_durationController.text);
    if (activity == null || minutes == null || minutes <= 0) return;
    final (weightKg, _) = _weightInfo;
    final kcal = MetTable.caloriesBurned(
        met: activity.met, weightKg: weightKg, minutes: minutes, intensity: _intensity);
    _caloriesController.text = kcal.toStringAsFixed(0);
    setState(() => _autoFilled = true);
  }

  /// Same selection logic the old dropdown ran, now fired by the pill chips.
  void _pickActivity(MetActivity a) {
    setState(() => _selectedActivity = a);
    if (_nameController.text.trim().isEmpty ||
        MetTable.activities.any((m) => m.name == _nameController.text.trim())) {
      _nameController.text = a.name;
    }
    _recalcCalories();
  }

  /// AI estimate for any free-text activity, factoring in intensity + weight.
  Future<void> _estimateWithAi() async {
    final name = _nameController.text.trim();
    final minutes = int.tryParse(_durationController.text);
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an exercise name to estimate')));
      return;
    }
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a duration in minutes')));
      return;
    }
    if (!aiService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set your Gemini key in Settings first')));
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final (weightKg, _) = _weightInfo;
      final kcal = await aiService.estimateCaloriesBurned(
          activity: name, minutes: minutes, intensity: _intensity, weightKg: weightKg);
      if (!mounted) return;
      _caloriesController.text = kcal.toStringAsFixed(0);
      setState(() => _autoFilled = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI error: $e')));
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _saveExercise() {
    if (_nameController.text.trim().isEmpty ||
        _durationController.text.isEmpty ||
        _caloriesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in name, duration and calories')));
      return;
    }
    final burned = double.tryParse(_caloriesController.text) ?? 0;
    if (burned > kMaxSingleEntryCalories) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'That\'s ${burned.toStringAsFixed(0)} kcal for one workout — '
              'over the ${kMaxSingleEntryCalories.toStringAsFixed(0)} kcal cap. Split it into multiple entries.')));
      return;
    }
    final exercise = Exercise(
      name: _nameController.text.trim(),
      durationMinutes: int.tryParse(_durationController.text) ?? 0,
      caloriesBurned: double.tryParse(_caloriesController.text) ?? 0,
      timestamp: DateTime.now(),
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      intensity: _intensity,
    );
    context.read<ExerciseProvider>().addExercise(exercise);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exercise logged!')));
    Navigator.of(context).pop();
  }

  /// Inline replacement for the AI-estimate button when no key is configured.
  /// The manual + MET path stays fully usable; only this affordance is locked.
  Widget _aiLockedCard(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
          context, HeroTransitionScaffold.route(const ApiKeyScreen())),
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s16, vertical: Spacing.s12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          border: Border.all(
              color: AppColors.statusInProgress,
              width: AppMotion.focusBorderWidth),
        ),
        child: Row(children: [
          const Icon(LucideIcons.lock,
              color: AppColors.statusInProgress, size: 16),
          const SizedBox(width: Spacing.s12),
          Expanded(
            child: Text('AI estimate locked — add API key',
                style: AppText.bodyS
                    .copyWith(color: AppColors.statusInProgress)),
          ),
          const Icon(LucideIcons.chevronRight,
              color: AppColors.statusInProgress, size: 16),
        ]),
      ),
    );
  }

  /// Horizontal scroll of MET pill chips. Selected = 1.5px healthRed border +
  /// accent glow; never a solid fill (focus rule, design/system.md).
  Widget _metPicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final a in MetTable.activities)
          Padding(
            padding: const EdgeInsets.only(right: Spacing.s8),
            child: _MetChip(
              activity: a,
              selected: _selectedActivity == a,
              accent: _accent,
              onTap: () => _pickActivity(a),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (weightKg, weightSource) = _weightInfo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Exercise'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: Spacing.s16),
              child: SizedBox(
                  width: Spacing.s48,
                  height: 2,
                  child: ColoredBox(color: _accent)),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('QUICK ESTIMATE (MET)', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          _metPicker(),
          const SizedBox(height: Spacing.s8),
          Text('Using $weightSource: ${weightKg.toStringAsFixed(1)} kg',
              style: AppText.tabular(
                  AppText.caption.copyWith(color: AppColors.textTertiary))),
          const SizedBox(height: Spacing.s20),
          _field(_nameController, 'Exercise name'),
          const SizedBox(height: Spacing.s16),
          _field(_durationController, 'Duration (minutes)',
              number: true, onChanged: (_) => _recalcCalories()),
          const SizedBox(height: Spacing.s16),
          Text('INTENSITY', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          DropdownButtonFormField<String>(
            initialValue: _intensity,
            isExpanded: true,
            dropdownColor: AppColors.surface3,
            style: AppText.bodyM,
            decoration: const InputDecoration(isDense: true),
            items: _intensities
                .map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase())))
                .toList(),
            onChanged: (v) {
              setState(() => _intensity = v ?? _intensity);
              _recalcCalories(); // intensity scales the MET estimate
            },
          ),
          const SizedBox(height: Spacing.s16),
          _field(_caloriesController, 'Calories burned',
              number: true, onChanged: (_) => setState(() => _autoFilled = false),
              suffix: _autoFilled
                  ? Padding(
                      padding: const EdgeInsets.only(right: Spacing.s8),
                      child: Text('AUTO',
                          style: AppText.caption.copyWith(color: _accent)))
                  : null),
          const SizedBox(height: Spacing.s12),
          if (context.watch<AiService>().hasValidKey)
            OutlinedButton.icon(
              onPressed: _aiLoading ? null : _estimateWithAi,
              style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(
                      color: _accent, width: AppMotion.focusBorderWidth),
                  padding:
                      const EdgeInsets.symmetric(vertical: Spacing.s12)),
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: Text(_aiLoading ? 'ESTIMATING…' : 'ESTIMATE WITH AI'),
            )
          else
            _aiLockedCard(context),
          const SizedBox(height: Spacing.s8),
          Text(
              'Works for any activity — uses the name, duration, intensity & your weight.',
              style: AppText.caption.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: Spacing.s16),
          _field(_notesController, 'Notes (optional)', maxLines: 3),
          const SizedBox(height: Spacing.s24),
          ElevatedButton(
            onPressed: _saveExercise,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: Spacing.s16)),
            child: const Text('SAVE EXERCISE'),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool number = false, int maxLines = 1, ValueChanged<String>? onChanged, Widget? suffix}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      style: number ? AppText.tabular(AppText.bodyM) : AppText.bodyM,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        suffixIcon: suffix,
        suffixIconConstraints:
            suffix == null ? null : const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}

/// One MET activity pill: textSecondary label, surface1 body. Selection flips
/// to a 1.5px healthRed border + the sanctioned 18% accent glow.
class _MetChip extends StatelessWidget {
  final MetActivity activity;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _MetChip({
    required this.activity,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.enter,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s12, vertical: Spacing.s8),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? accent : AppColors.divider,
            width: selected ? AppMotion.focusBorderWidth : 1,
          ),
          boxShadow: selected ? AppMotion.accentGlow(accent) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            activity.name,
            style: AppText.bodyS.copyWith(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary),
          ),
          const SizedBox(width: Spacing.s4),
          Text(
            '${activity.met} MET',
            style: AppText.tabular(
                AppText.caption.copyWith(color: AppColors.textTertiary)),
          ),
        ]),
      ),
    );
  }
}
