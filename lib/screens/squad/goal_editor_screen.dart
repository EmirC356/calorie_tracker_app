import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/squad_goal.dart';
import '../../theme/app_theme.dart';

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
      appBar: AppBar(
        title: const Text('MY GOAL'),
        titleTextStyle: const TextStyle(color: kNavy, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.4),
        iconTheme: const IconThemeData(color: kNavy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('CALORIES', style: neonLabel(kNavy, size: 12)),
          const SizedBox(height: 8),
          _modeToggle(),
          if (_mode != CalorieMode.none) ...[
            const SizedBox(height: 10),
            _numField(_calTarget, _mode == CalorieMode.cap ? 'Daily cap (kcal)' : 'Daily floor (kcal)'),
          ],
          const SizedBox(height: 20),
          Text('EXERCISE', style: neonLabel(kNavy, size: 12)),
          const SizedBox(height: 8),
          _numField(_exMin, 'Min minutes / day (optional)'),
          const SizedBox(height: 10),
          _numField(_burnedMin, 'Min calories burned / day (optional)'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(preview.isValid ? kNavy : kBorderDim),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PREVIEW', style: neonLabel(preview.isValid ? kNavy : kTextDim, size: 11)),
              const SizedBox(height: 6),
              Text(preview.summary, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: kWhite,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('SAVE GOAL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ]),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorderDim)),
      child: Row(children: [
        _modeTab('OFF', CalorieMode.none),
        _modeTab('CAP (≤)', CalorieMode.cap),
        _modeTab('FLOOR (≥)', CalorieMode.floor),
      ]),
    );
  }

  Widget _modeTab(String label, CalorieMode m) {
    final sel = _mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = m),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: sel ? kNavy : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: sel ? kBg : kNavy, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: kText),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label),
      );
}
