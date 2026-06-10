import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/met_table.dart';
import '../models/index.dart';
import '../providers/exercise_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/weight_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import 'settings/api_key_screen.dart';

class ExerciseLoggingScreen extends StatefulWidget {
  const ExerciseLoggingScreen({super.key});

  @override
  State<ExerciseLoggingScreen> createState() => _ExerciseLoggingScreenState();
}

class _ExerciseLoggingScreenState extends State<ExerciseLoggingScreen> {
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
          context, MaterialPageRoute(builder: (_) => const ApiKeyScreen())),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAmber),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline, color: kAmber, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('AI estimate locked — add API key',
                style: TextStyle(color: kAmber, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const Icon(Icons.chevron_right, color: kAmber, size: 18),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (weightKg, weightSource) = _weightInfo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('LOG EXERCISE'),
        titleTextStyle: const TextStyle(color: kPink, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, shadows: [Shadow(color: kPink, blurRadius: 8)]),
        iconTheme: const IconThemeData(color: kPink),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('QUICK ESTIMATE (MET)', style: neonLabel(kPink, size: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<MetActivity>(
            initialValue: _selectedActivity,
            isExpanded: true,
            dropdownColor: kCard,
            style: const TextStyle(color: kText, fontSize: 14),
            hint: const Text('Pick an activity to auto-calc calories', style: TextStyle(color: kTextDim, fontSize: 13)),
            decoration: _decoration('Activity', kPink),
            items: MetTable.activities
                .map((a) => DropdownMenuItem(
                    value: a,
                    child: Text('${a.name}  •  ${a.met} MET', overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (a) {
              if (a == null) return;
              _selectedActivity = a;
              if (_nameController.text.trim().isEmpty ||
                  MetTable.activities.any((m) => m.name == _nameController.text.trim())) {
                _nameController.text = a.name;
              }
              _recalcCalories();
            },
          ),
          const SizedBox(height: 6),
          Text('Using $weightSource: ${weightKg.toStringAsFixed(1)} kg',
              style: const TextStyle(color: kTextDim, fontSize: 11)),
          const SizedBox(height: 18),
          _field(_nameController, 'Exercise name', kPink),
          const SizedBox(height: 14),
          _field(_durationController, 'Duration (minutes)', kPink,
              number: true, onChanged: (_) => _recalcCalories()),
          const SizedBox(height: 14),
          Text('INTENSITY', style: neonLabel(kPink, size: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _intensity,
            isExpanded: true,
            dropdownColor: kCard,
            style: const TextStyle(color: kText, fontSize: 14),
            decoration: _decoration('Intensity', kPink),
            items: _intensities
                .map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase())))
                .toList(),
            onChanged: (v) {
              setState(() => _intensity = v ?? _intensity);
              _recalcCalories(); // intensity scales the MET estimate
            },
          ),
          const SizedBox(height: 14),
          _field(_caloriesController, 'Calories burned', kOrange,
              number: true, onChanged: (_) => setState(() => _autoFilled = false),
              suffix: _autoFilled
                  ? const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('AUTO', style: TextStyle(color: kPink, fontSize: 11, fontWeight: FontWeight.bold)))
                  : null),
          const SizedBox(height: 10),
          if (context.watch<AiService>().hasValidKey)
            OutlinedButton.icon(
              onPressed: _aiLoading ? null : _estimateWithAi,
              style: OutlinedButton.styleFrom(
                  foregroundColor: kPink, side: const BorderSide(color: kPink),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: _aiLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPink))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_aiLoading ? 'ESTIMATING...' : 'ESTIMATE WITH AI',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            )
          else
            _aiLockedCard(context),
          const SizedBox(height: 6),
          const Text('Works for any activity — uses the name, duration, intensity & your weight.',
              style: TextStyle(color: kTextDim, fontSize: 11)),
          const SizedBox(height: 14),
          _field(_notesController, 'Notes (optional)', kPink, maxLines: 3),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveExercise,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: kPink,
              foregroundColor: kBg,
            ),
            child: const Text('SAVE EXERCISE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ]),
      ),
    );
  }

  InputDecoration _decoration(String label, Color accent, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kTextDim, fontSize: 13),
        isDense: true,
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accent.withValues(alpha: 0.4))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accent)),
        filled: true,
        fillColor: kSurface,
      );

  Widget _field(TextEditingController c, String label, Color accent,
      {bool number = false, int maxLines = 1, ValueChanged<String>? onChanged, Widget? suffix}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      style: const TextStyle(color: kText, fontSize: 14),
      onChanged: onChanged,
      decoration: _decoration(label, accent, suffix: suffix),
    );
  }
}
