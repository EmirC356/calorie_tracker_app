import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/exercise_provider.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edit_entry_sheets.dart';
import '../exercise_logging_screen.dart';
import 'health_chips.dart';

/// Fitness sub-tab of the Health shell — today's exercises list with a log FAB.
class FitnessTabScreen extends StatelessWidget {
  const FitnessTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FITNESS TODAY'),
        titleTextStyle: const TextStyle(color: kPink, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, shadows: [Shadow(color: kPink, blurRadius: 8)])),
      body: Consumer<ExerciseProvider>(
        builder: (_, ep, __) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (ep.todaysExercises.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No exercises logged today', style: Theme.of(context).textTheme.bodySmall),
              ))
            else
              ...ep.todaysExercises.map((ex) => _ExerciseCard(
                    exercise: ex,
                    onDelete: () => ep.deleteExercise(ex.id!),
                    onEdit: (updated) => ep.updateExercise(updated),
                  )),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLoggingScreen())),
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
