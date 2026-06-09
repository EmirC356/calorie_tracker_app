import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/index.dart';
import '../providers/profile_provider.dart';
import '../providers/weight_provider.dart';
import '../theme/app_theme.dart';

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
  late Goal _goal;

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
  }

  @override
  void dispose() {
    _height.dispose();
    _age.dispose();
    _weight.dispose();
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
      );

  Future<void> _save() async {
    final profile = _currentProfile();
    if (!profile.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid height and age')));
      return;
    }
    await context.read<ProfileProvider>().save(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE & GOALS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: _numField(_height, 'Height (cm)', kCyan)),
            const SizedBox(width: 12),
            Expanded(child: _numField(_age, 'Age', kCyan)),
          ]),
          const SizedBox(height: 12),
          _numField(_weight, 'Current weight (kg) — fallback if none logged', kNeonGreen),
          const SizedBox(height: 18),
          Text('SEX', style: neonLabel(kCyan, size: 12)),
          const SizedBox(height: 8),
          _segmented<Sex>(
            values: Sex.values,
            current: _sex,
            label: (s) => s == Sex.male ? 'MALE' : 'FEMALE',
            onChanged: (s) => setState(() => _sex = s),
            accent: kCyan,
          ),
          const SizedBox(height: 18),
          Text('ACTIVITY LEVEL', style: neonLabel(kCyan, size: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: _activity,
            isExpanded: true,
            dropdownColor: kCard,
            style: const TextStyle(color: kText, fontSize: 14),
            decoration: _decoration(kCyan),
            items: ActivityLevel.values
                .map((a) => DropdownMenuItem(
                    value: a, child: Text(_activityLabels[a]!, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (a) => setState(() => _activity = a ?? _activity),
          ),
          const SizedBox(height: 18),
          Text('GOAL', style: neonLabel(kCyan, size: 12)),
          const SizedBox(height: 8),
          _segmented<Goal>(
            values: Goal.values,
            current: _goal,
            label: (g) => g.name.toUpperCase(),
            onChanged: (g) => setState(() => _goal = g),
            accent: kNeonGreen,
          ),
          const SizedBox(height: 20),
          _preview(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: kCyan,
              foregroundColor: kBg,
            ),
            child: const Text('SAVE PROFILE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ]),
      ),
    );
  }

  Widget _preview() {
    final profile = _currentProfile();
    final weight = _effectiveWeight;
    if (!profile.isComplete || weight == null || weight <= 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: neonBox(kBorderDim),
        child: const Text(
          'Enter height, age and a weight (or log one) to see your targets.',
          style: TextStyle(color: kTextDim, fontSize: 13),
        ),
      );
    }
    final tdee = profile.tdee(weight);
    final calTarget = profile.calorieTarget(weight);
    final proTarget = profile.proteinTargetGrams(weight);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kCyan),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR TARGETS', style: neonLabel(kCyan, size: 13)),
        const SizedBox(height: 4),
        Text('Based on ${weight.toStringAsFixed(1)} kg',
            style: const TextStyle(color: kTextDim, fontSize: 11)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('TDEE', tdee.toStringAsFixed(0), 'kcal', kTextDim),
          _stat('TARGET', calTarget.toStringAsFixed(0), 'kcal', kCyan),
          _stat('PROTEIN', proTarget.toStringAsFixed(0), 'g', kNeonRed),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value, String unit, Color color) => Column(children: [
        Text(label, style: const TextStyle(color: kTextDim, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18, shadows: textGlow(color))),
        Text(unit, style: const TextStyle(color: kTextDim, fontSize: 10)),
      ]);

  Widget _numField(TextEditingController c, String label, Color accent) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: const TextStyle(color: kText, fontSize: 14),
      onChanged: (_) => setState(() {}), // refresh preview
      decoration: _decoration(accent).copyWith(
        labelText: label,
        labelStyle: const TextStyle(color: kTextDim, fontSize: 13),
      ),
    );
  }

  InputDecoration _decoration(Color accent) => InputDecoration(
        isDense: true,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accent.withValues(alpha: 0.4))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accent)),
        filled: true,
        fillColor: kSurface,
      );

  Widget _segmented<T>({
    required List<T> values,
    required T current,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderDim),
      ),
      child: Row(
        children: values.map((v) {
          final selected = v == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label(v),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selected ? kBg : accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
