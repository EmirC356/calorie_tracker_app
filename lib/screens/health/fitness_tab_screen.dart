import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/exercise_provider.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edit_entry_sheets.dart';
import '../../widgets/undo_delete.dart';
import '../../widgets/date_nav_bar.dart';
import '../exercise_logging_screen.dart';
import 'health_chips.dart';

/// Fitness sub-tab of the Health shell — the selected day's exercises with a
/// date navigator to browse previous days. The FAB always logs to today.
class FitnessTabScreen extends StatefulWidget {
  const FitnessTabScreen({super.key});

  @override
  State<FitnessTabScreen> createState() => _FitnessTabScreenState();
}

class _FitnessTabScreenState extends State<FitnessTabScreen> {
  late final ExerciseProvider _provider;
  DateTime _date = dateOnly(DateTime.now());
  List<Exercise> _exercises = [];

  bool get _isToday => _date == dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _provider = context.read<ExerciseProvider>();
    _provider.addListener(_reload);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _provider.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await _provider.getExercisesByDate(_date);
    if (mounted) setState(() => _exercises = list);
  }

  void _setDate(DateTime d) {
    setState(() => _date = d);
    _reload();
  }

  Future<void> _logExercise() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLoggingScreen()));
    if (mounted) _setDate(dateOnly(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FITNESS'),
        titleTextStyle: const TextStyle(color: kPink, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, shadows: [Shadow(color: kPink, blurRadius: 8)])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DateNavBar(selected: _date, accent: kPink, onChanged: _setDate),
          const SizedBox(height: 12),
          if (_exercises.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(_isToday ? 'No exercises logged today' : 'No exercises logged on this day',
                  style: Theme.of(context).textTheme.bodySmall),
            ))
          else
            ..._exercises.map((ex) => _ExerciseCard(
                  exercise: ex,
                  onDelete: () => deleteExerciseWithUndo(ScaffoldMessenger.of(context), _provider, ex),
                  onEdit: (updated) => _provider.updateExercise(updated),
                )),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logExercise,
        backgroundColor: kPink,
        foregroundColor: kBg,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onDelete;
  final ValueChanged<Exercise> onEdit;
  const _ExerciseCard({required this.exercise, required this.onDelete, required this.onEdit});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kPink, width: 1)),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(exercise.name, style: neonLabel(kPink, size: 15)),
          const SizedBox(height: 4),
          Text(DateFormat('MMM d, HH:mm').format(exercise.timestamp), style: const TextStyle(color: kTextDim, fontSize: 12)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            DetailChip('Duration', '${exercise.durationMinutes} min', kPink),
            DetailChip('Burned', '${exercise.caloriesBurned.toStringAsFixed(0)} kcal', kOrange),
            DetailChip('Intensity', exercise.intensity.toUpperCase(), kNeonGreen),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final edited = await showEditExerciseSheet(context, exercise);
                if (edited != null) onEdit(edited);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('EDIT'),
              style: OutlinedButton.styleFrom(foregroundColor: kPink, side: const BorderSide(color: kPink)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); onDelete(); },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('DELETE'),
              style: ElevatedButton.styleFrom(backgroundColor: kNeonRed, foregroundColor: Colors.white),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: neonBox(kPink),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exercise.name, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${exercise.durationMinutes} min  •  ${exercise.intensity}', style: const TextStyle(color: kTextDim, fontSize: 12)),
          ])),
          StatBadge('${exercise.caloriesBurned.toStringAsFixed(0)} kcal', kOrange),
        ]),
      ),
    );
  }
}
