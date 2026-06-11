import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  String? _birthday;
  bool _showCalorie = false; // the two collapsible goal sections
  bool _showExercise = false;

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
    _showCalorie = p.calorieGoalMode != CalorieMode.none;
    _showExercise = p.weeklyExerciseSessions != null;
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
        final auth = context.read<AuthProvider>();
        final uid = auth.firebaseUser?.uid;
        if (uid != null) {
          final svc = context.read<SquadProvider>().service;
          await svc.syncProfileGoalsToAllSquads(uid, profile.healthGoalSnapshot);
          // Birthday → squad-wide annual event (cleared when unset).
          final b = profile.birthday != null ? DateTime.tryParse(profile.birthday!) : null;
          await svc.syncBirthdayEvent(uid,
              month: b?.month, day: b?.day, displayName: auth.appUser?.displayName);
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
          _birthdayField(),
          const SizedBox(height: Spacing.s24),
          Text('HEALTH GOALS', style: AppText.caption),
          const SizedBox(height: Spacing.s4),
          Text('Set the goals you want to hit — these become your squad goal.',
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: Spacing.s12),
          _sectionButton(
            'Track Daily Calorie',
            Icons.local_fire_department,
            expanded: _showCalorie,
            active: _calMode != CalorieMode.none,
            onTap: () => setState(() => _showCalorie = !_showCalorie),
          ),
          if (_showCalorie) _calorieSection(),
          const SizedBox(height: Spacing.s12),
          _sectionButton(
            'Track Weekly Exercise Sessions',
            Icons.fitness_center,
            expanded: _showExercise,
            active: _weeklySessions != null,
            onTap: () => setState(() => _showExercise = !_showExercise),
          ),
          if (_showExercise) _exerciseSection(),
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

  Widget _birthdayField() {
    final b = _birthday != null ? DateTime.tryParse(_birthday!) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('BIRTHDAY', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickBirthday,
            icon: const Icon(Icons.cake_outlined, size: 18),
            label: Text(b != null ? DateFormat('MMM d, yyyy').format(b) : 'Set birthday'),
          ),
        ),
        if (_birthday != null)
          IconButton(
            tooltip: 'Clear birthday',
            onPressed: () => setState(() => _birthday = null),
            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
          ),
      ]),
      const SizedBox(height: Spacing.s4),
      Text('Birthday lets us auto-update your age and lets squadmates celebrate with you.',
          style: AppText.caption.copyWith(color: AppColors.textTertiary)),
    ]);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = (_birthday != null ? DateTime.tryParse(_birthday!) : null) ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 13, now.month, now.day), // 13+ only
    );
    if (picked != null) {
      setState(() => _birthday =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  /// Collapsible goal-section header button.
  Widget _sectionButton(String title, IconData icon,
      {required bool expanded, required bool active, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.s12, vertical: Spacing.s12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          border: Border.all(
              color: active ? AppColors.healthRed : AppColors.surface2,
              width: active ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: active ? AppColors.healthRed : AppColors.textSecondary),
          const SizedBox(width: Spacing.s12),
          Expanded(child: Text(title, style: AppText.bodyL)),
          if (active) ...[
            const Icon(Icons.check_circle, size: 16, color: AppColors.healthRed),
            const SizedBox(width: Spacing.s8),
          ],
          Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  /// Calorie goal: the sex/activity/direction inputs that drive the TDEE
  /// *suggestion* (just a hint), then the actual goal the user enters.
  Widget _calorieSection() {
    final weight = _effectiveWeight;
    final profile = _currentProfile();
    final suggestion = (weight != null && weight > 0 && profile.isComplete)
        ? profile.calorieTarget(weight).round()
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.s4, Spacing.s12, Spacing.s4, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('SEX', style: AppText.caption),
        const SizedBox(height: Spacing.s8),
        _segmented<Sex>(
          values: Sex.values, current: _sex,
          label: (s) => s == Sex.male ? 'MALE' : 'FEMALE',
          onChanged: (s) => setState(() => _sex = s),
        ),
        const SizedBox(height: Spacing.s16),
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
        const SizedBox(height: Spacing.s16),
        Text('GOAL DIRECTION', style: AppText.caption),
        const SizedBox(height: Spacing.s8),
        _segmented<DietGoal>(
          values: DietGoal.values, current: _goal,
          label: (g) => g.name.toUpperCase(),
          onChanged: (g) => setState(() => _goal = g),
        ),
        const SizedBox(height: Spacing.s16),
        _preview(), // YOUR TARGETS — suggestions only, not the goal
        const SizedBox(height: Spacing.s16),
        Text('YOUR CALORIE GOAL', style: AppText.caption),
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
          _numField(_calTarget, 'Goal target (kcal/day)'),
          if (suggestion != null) ...[
            const SizedBox(height: Spacing.s8),
            GestureDetector(
              onTap: () => setState(() => _calTarget.text = suggestion.toString()),
              child: Text('Suggested: $suggestion kcal/day  ·  tap to use',
                  style: AppText.caption.copyWith(color: AppColors.healthRed)),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _exerciseSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.s4, Spacing.s8, Spacing.s4, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.healthRed,
          title: Text('Enable weekly exercise goal', style: AppText.bodyL),
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
      ]),
    );
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
