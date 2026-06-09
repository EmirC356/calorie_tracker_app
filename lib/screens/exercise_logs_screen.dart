import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../providers/exercise_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_entry_sheets.dart';

class ExerciseLogsScreen extends StatefulWidget {
  const ExerciseLogsScreen({super.key});

  @override
  State<ExerciseLogsScreen> createState() => _ExerciseLogsScreenState();
}

class _ExerciseLogsScreenState extends State<ExerciseLogsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exercises = await context.read<ExerciseProvider>().getExercisesByDate(_selectedDate);
    if (mounted) setState(() => _exercises = exercises);
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(data: Theme.of(context), child: child!),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  void _showDetail(Exercise ex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kPink, width: 1)),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ex.name, style: neonLabel(kPink, size: 15)),
          const SizedBox(height: 4),
          Text(DateFormat('MMM d, HH:mm').format(ex.timestamp), style: const TextStyle(color: kTextDim, fontSize: 12)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Chip('Duration', '${ex.durationMinutes} min', kPink),
            _Chip('Burned', '${ex.caloriesBurned.toStringAsFixed(0)} kcal', kOrange),
            _Chip('Intensity', ex.intensity.toUpperCase(), kNeonGreen),
          ]),
          if (ex.notes != null && ex.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(ex.notes!, style: const TextStyle(color: kTextDim, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                final provider = context.read<ExerciseProvider>();
                Navigator.pop(context);
                final edited = await showEditExerciseSheet(context, ex);
                if (edited != null) {
                  await provider.updateExercise(edited);
                  if (mounted) _load();
                }
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('EDIT'),
              style: OutlinedButton.styleFrom(foregroundColor: kPink, side: const BorderSide(color: kPink)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await context.read<ExerciseProvider>().deleteExercise(ex.id!);
                _load();
              },
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
    double totalCal = 0;
    int totalDur = 0;
    for (final e in _exercises) {
      totalCal += e.caloriesBurned;
      totalDur += e.durationMinutes;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('EXERCISE LOGS'),
        titleTextStyle: const TextStyle(color: kPink, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, shadows: [Shadow(color: kPink, blurRadius: 8)]),
        iconTheme: const IconThemeData(color: kPink),
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: kSurface,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: neonLabel(kPink, size: 16)),
            OutlinedButton(
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(foregroundColor: kPink, side: const BorderSide(color: kPink)),
              child: const Text('Change Date'),
            ),
          ]),
        ),
        Expanded(
          child: _exercises.isEmpty
            ? Center(child: Text('No exercises on this date', style: Theme.of(context).textTheme.bodySmall))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _exercises.length,
                itemBuilder: (_, i) {
                  final ex = _exercises[i];
                  return GestureDetector(
                    onTap: () => _showDetail(ex),
                    onLongPress: () => _showDetail(ex),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: neonBox(kPink),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ex.name, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('${ex.durationMinutes} min  •  ${ex.intensity}', style: const TextStyle(color: kTextDim, fontSize: 12)),
                        ])),
                        _Badge('${ex.caloriesBurned.toStringAsFixed(0)} kcal', kOrange),
                      ]),
                    ),
                  );
                },
              ),
        ),
        if (_exercises.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(kPink, radius: 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _Chip('Duration', '$totalDur min', kPink),
              _Chip('Burned', '${totalCal.toStringAsFixed(0)} kcal', kOrange),
              _Chip('Sessions', '${_exercises.length}', kNeonGreen),
            ]),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: kTextDim, fontSize: 10)),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, shadows: textGlow(color))),
  ]);
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
  );
}
