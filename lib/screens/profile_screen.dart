import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/index.dart';
import '../providers/profile_provider.dart';
import '../providers/weight_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/squad_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _height;
  late final TextEditingController _age;
  late final TextEditingController _weight;
  late Sex _sex;
  late ActivityLevel _activity;
  late DietGoal _goal;
  // Health Goals
  late CalorieMode _calMode;
  late final TextEditingController _calTarget;
  int? _weeklySessions; // null = exercise goal off
  int _minMinutes = 20;
  String? _birthday; // preserved across saves (date-picker UI lands in Task 6)

  static const _activityLabels = {
    ActivityLevel.sedentary: 'Sedentary (little/no exercise)',
    ActivityLevel.light: 'Light (1–3 days/wk)',
    ActivityLevel.moderate: 'Moderate (3–5 days/wk)',
    ActivityLevel.active: 'Active (6–7 days/wk)',
    ActivityLevel.veryActive: 'Very active (hard exercise/job)',
  };

  @override
  void initState() {
    super.initState();
    context.read<WeightProvider>().loadEntries();
    final p = context.read<ProfileProvider>().profile ?? UserProfile.empty;
    _height = TextEditingController(text: p.heightCm > 0 ? p.heightCm.toStringAsFixed(0) : '');
    _age = TextEditingController(text: p.age > 0 ? '${p.age}' : '');
    _weight = TextEditingController(
        text: p.fallbackWeightKg != null ? p.fallbackWeightKg!.toStringAsFixed(1) : '');
    _sex = p.sex;
    _activity = p.activity;
    _goal = p.goal;
    _calMode = p.calorieGoalMode;
    _calTarget = TextEditingController(
        text: p.calorieGoalTarget != null ? p.calorieGoalTarget!.round().toString() : '');
    _weeklySessions = p.weeklyExerciseSessions;
    _minMinutes = p.minSessionMinutes;
    _birthday = p.birthday;
  }

  @override
  void dispose() {
    _height.dispose();
    _age.dispose();
    _weight.dispose();
    _calTarget.dispose();
    super.dispose();
  }

  double? get _effectiveWeight {
    final latest = context.read<WeightProvider>().latest?.weight;
    return latest ?? double.tryParse(_weight.text);
  }

  UserProfile _currentProfile() => UserProfile(
        heightCm: double.tryParse(_height.text) ?? 0,
        age: int.tryParse(_age.text) ?? 0,
        sex: _sex,
        activity: _activity,
        goal: _goal,
        fallbackWeightKg: double.tryParse(_weight.text),
        calorieGoalMode: _calMode,
        calorieGoalTarget:
            _calMode == CalorieMode.none ? null : double.tryParse(_calTarget.text),
        weeklyExerciseSessions: _weeklySessions,
        minSessionMinutes: _minMinutes,
        birthday: _birthday,
      );

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    final profile = _currentProfile();
    if (!profile.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid height and age')));
      return;
    }
    await context.read<ProfileProvider>().save(profile);
    // Propagate the Health Goals to every squad (best-effort; only when signed
    // in). profileGoalSnapshot is refreshed everywhere; the effective goal
    // updates only where the member still inherits from the profile.
    if (mounted) {
      try {
        final uid = context.read<AuthProvider>().firebaseUser?.uid;
        if (uid != null) {
          await context
              .read<SquadProvider>()
              .service
              .syncProfileGoalsToAllSquads(uid, profile.healthGoalSnapshot);
        }
      } catch (_) {/* best-effort — never block a local profile save */}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Goals')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: _numField(_height, 'Height (cm)')),
            const SizedBox(width: Spacing.s12),
            Expanded(child: _numField(_age, 'Age')),
          ]),
          const SizedBox(height: Spacing.s12),
          _numField(_weight, 'Current weight (kg) — fallback if none logged'),
          const SizedBox(height: Spacing.s20),
          Text('SEX', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          _segmented<Sex>(
            values: Sex.values,
            current: _sex,
            label: (s) => s == Sex.male ? 'MALE' : 'FEMALE',
            onChanged: (s) => setState(() => _sex = s),
          ),
          const SizedBox(height: Spacing.s20),
          Text('ACTIVITY LEVEL', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: _activity,
            isExpanded: true,
            dropdownColor: AppColors.surface3,
            style: AppText.bodyM,
            decoration: const InputDecoration(isDense: true),
            items: ActivityLevel.values
                .map((a) => DropdownMenuItem(
                    value: a, child: Text(_activityLabels[a]!, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (a) => setState(() => _activity = a ?? _activity),
          ),
          const SizedBox(height: Spacing.s20),
          Text('GOAL', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          _segmented<DietGoal>(
            values: DietGoal.values,
            current: _goal,
            label: (g) => g.name.toUpperCase(),
            onChanged: (g) => setState(() => _goal = g),
          ),
          const SizedBox(height: Spacing.s20),
          _preview(),
          const SizedBox(height: Spacing.s24),
          _healthGoals(),
          const SizedBox(height: Spacing.s24),
          OutlinedButton(
            onPressed: _save,
            child: const Text('Save profile'),
          ),
        ]),
      ),
    );
  }

  Widget _preview() {
    final profile = _currentProfile();
    final weight = _effectiveWeight;
    if (!profile.isComplete || weight == null || weight <= 0) {
      return Text(
        'Enter height, age and a weight (or log one) to see your targets.',
        style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
      );
    }
    final tdee = profile.tdee(weight);
    final calTarget = profile.calorieTarget(weight);
    final proTarget = profile.proteinTargetGrams(weight);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('YOUR TARGETS', style: AppText.caption),
      const SizedBox(height: Spacing.s4),
      Text('Based on ${weight.toStringAsFixed(1)} kg',
          style: AppText.tabular(
              AppText.caption.copyWith(color: AppColors.textTertiary))),
      const SizedBox(height: Spacing.s12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _stat('TDEE', tdee.toStringAsFixed(0), 'kcal',
            AppColors.textSecondary),
        _stat('TARGET', calTarget.toStringAsFixed(0), 'kcal',
            AppColors.healthRed),
        _stat('PROTEIN', proTarget.toStringAsFixed(0), 'g',
            AppColors.textPrimary),
      ]),
    ]);
  }

  Widget _healthGoals() {
    final weight = _effectiveWeight;
    final profile = _currentProfile();
    final suggestion = (weight != null && weight > 0 && profile.isComplete)
        ? profile.calorieTarget(weight).round()
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('HEALTH GOALS', style: AppText.caption),
      const SizedBox(height: Spacing.s4),
      Text('Becomes your primary squad goal — no Calendar entry needed.',
          style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: Spacing.s16),
      Text('CALORIE GOAL', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      _segmented<CalorieMode>(
        values: const [CalorieMode.none, CalorieMode.cap, CalorieMode.floor],
        current: _calMode,
        label: (m) => switch (m) {
          CalorieMode.none => 'NONE',
          CalorieMode.cap => 'CAP ≤',
          CalorieMode.floor => 'FLOOR ≥',
        },
        onChanged: (m) => setState(() {
          _calMode = m;
          if (m != CalorieMode.none && _calTarget.text.isEmpty && suggestion != null) {
            _calTarget.text = suggestion.toString();
          }
        }),
      ),
      if (_calMode != CalorieMode.none) ...[
        const SizedBox(height: Spacing.s12),
        _numField(_calTarget, 'Target (kcal/day)'),
        if (suggestion != null) ...[
          const SizedBox(height: Spacing.s8),
          GestureDetector(
            onTap: () => setState(() => _calTarget.text = suggestion.toString()),
            child: Text('Suggested: $suggestion kcal/day  ·  tap to use',
                style: AppText.caption.copyWith(color: AppColors.healthRed)),
          ),
        ],
      ],
      const SizedBox(height: Spacing.s16),
      Text('EXERCISE GOAL', style: AppText.caption),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.healthRed,
        title: Text('Track weekly exercise sessions', style: AppText.bodyL),
        subtitle: Text('A session counts when you log an exercise ≥ $_minMinutes min',
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
        value: _weeklySessions != null,
        onChanged: (on) => setState(() => _weeklySessions = on ? (_weeklySessions ?? 3) : null),
      ),
      if (_weeklySessions != null) ...[
        _stepperRow('Sessions per week', _weeklySessions!, 1, 14,
            (v) => setState(() => _weeklySessions = v)),
        _stepperRow('Min minutes per session', _minMinutes, 5, 180,
            (v) => setState(() => _minMinutes = v), step: 5),
      ],
    ]);
  }

  Widget _stepperRow(String label, int value, int min, int max, ValueChanged<int> onChanged,
      {int step = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.s4),
      child: Row(children: [
        Expanded(child: Text(label, style: AppText.bodyM)),
        IconButton(
          onPressed: value > min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
        ),
        SizedBox(
          width: 36,
          child: Text('$value',
              textAlign: TextAlign.center, style: AppText.tabular(AppText.bodyL)),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add_circle_outline, color: AppColors.healthRed),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, String unit, Color color) =>
      Column(children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: Spacing.s4),
        Text(value,
            style: AppText.tabular(AppText.displayM.copyWith(color: color))),
        Text(unit, style: AppText.caption),
      ]);

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: AppText.tabular(AppText.bodyM),
      onChanged: (_) => setState(() {}), // refresh preview
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
      ),
    );
  }

  Widget _segmented<T>({
    required List<T> values,
    required T current,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
  }) {
    return Row(
      children: [
        for (final (i, v) in values.indexed) ...[
          if (i > 0) const SizedBox(width: Spacing.s8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: AppMotion.enter,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(
                    color: v == current
                        ? AppColors.healthRed
                        : AppColors.surface2,
                    width: v == current ? AppMotion.focusBorderWidth : 1,
                  ),
                  boxShadow: v == current
                      ? AppMotion.accentGlow(AppColors.healthRed)
                      : null,
                ),
                child: Text(label(v),
                    textAlign: TextAlign.center,
                    style: AppText.bodyS.copyWith(
                        color: v == current
                            ? AppColors.healthRed
                            : AppColors.textSecondary)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
