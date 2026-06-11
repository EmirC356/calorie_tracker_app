import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/squad_goal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Edits a per-squad [SquadGoal]. Pops with the new goal, or null if cancelled.
/// At least one sub-goal must be active to save.
class GoalEditorScreen extends StatefulWidget {
  final SquadGoal initial;
  const GoalEditorScreen({super.key, required this.initial});

  @override
  State<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends State<GoalEditorScreen> {
  late CalorieMode _mode;
  late final TextEditingController _calTarget;
  late final TextEditingController _exMin;
  late final TextEditingController _burnedMin;

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    _mode = g.calorieMode;
    _calTarget = TextEditingController(text: g.calorieTarget?.toString() ?? '');
    _exMin = TextEditingController(text: g.exerciseMinutesMin?.toString() ?? '');
    _burnedMin = TextEditingController(text: g.caloriesBurnedMin?.toString() ?? '');
  }

  @override
  void dispose() {
    _calTarget.dispose();
    _exMin.dispose();
    _burnedMin.dispose();
    super.dispose();
  }

  SquadGoal _build() {
    int? parse(TextEditingController c) => c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());
    return SquadGoal(
      calorieMode: _mode,
      calorieTarget: _mode == CalorieMode.none ? null : parse(_calTarget),
      exerciseMinutesMin: parse(_exMin),
      caloriesBurnedMin: parse(_burnedMin),
    );
  }

  void _save() {
    final goal = _build();
    if (!goal.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set at least one sub-goal (calories, exercise, or burned)')));
      return;
    }
    Navigator.pop(context, goal);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _build();
    return Scaffold(
      appBar: AppBar(title: const Text('My Goal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('CALORIES', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          _modeToggle(),
          if (_mode != CalorieMode.none) ...[
            const SizedBox(height: Spacing.s12),
            _numField(_calTarget, _mode == CalorieMode.cap ? 'Daily cap (kcal)' : 'Daily floor (kcal)'),
          ],
          const SizedBox(height: Spacing.s20),
          Text('EXERCISE', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          _numField(_exMin, 'Min minutes / day (optional)'),
          const SizedBox(height: Spacing.s12),
          _numField(_burnedMin, 'Min calories burned / day (optional)'),
          const SizedBox(height: Spacing.s24),
          Text('PREVIEW', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          Text(preview.summary,
              style: AppText.titleM.copyWith(
                  color: preview.isValid
                      ? AppColors.textPrimary
                      : AppColors.textTertiary)),
          const SizedBox(height: Spacing.s20),
          OutlinedButton(
            onPressed: _save,
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.squadBlue,
                side: const BorderSide(
                    color: AppColors.squadBlue, width: 1.5)),
            child: const Text('Save goal'),
          ),
        ]),
      ),
    );
  }

  Widget _modeToggle() {
    return Row(children: [
      _modeTab('OFF', CalorieMode.none),
      const SizedBox(width: Spacing.s8),
      _modeTab('CAP (≤)', CalorieMode.cap),
      const SizedBox(width: Spacing.s8),
      _modeTab('FLOOR (≥)', CalorieMode.floor),
    ]);
  }

  Widget _modeTab(String label, CalorieMode m) {
    final sel = _mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = m),
        child: AnimatedContainer(
          duration: AppMotion.enter,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(
              color: sel ? AppColors.squadBlue : AppColors.surface2,
              width: sel ? AppMotion.focusBorderWidth : 1,
            ),
            boxShadow:
                sel ? AppMotion.accentGlow(AppColors.squadBlue) : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppText.bodyS.copyWith(
                  color: sel
                      ? AppColors.squadBlue
                      : AppColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppText.tabular(AppText.bodyM),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label),
      );
}
