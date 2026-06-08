import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/index.dart';
import '../providers/exercise_provider.dart';

class ExerciseLoggingScreen extends StatefulWidget {
  const ExerciseLoggingScreen({Key? key}) : super(key: key);

  @override
  State<ExerciseLoggingScreen> createState() => _ExerciseLoggingScreenState();
}

class _ExerciseLoggingScreenState extends State<ExerciseLoggingScreen> {
  final _exerciseController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _notesController = TextEditingController();

  String _intensity = 'medium';
  final List<String> _intensities = ['low', 'medium', 'high'];

  @override
  void dispose() {
    _exerciseController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveExercise() {
    if (_exerciseController.text.isEmpty ||
        _durationController.text.isEmpty ||
        _caloriesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      final exercise = Exercise(
        name: _exerciseController.text,
        durationMinutes: int.parse(_durationController.text),
        caloriesBurned: double.parse(_caloriesController.text),
        timestamp: DateTime.now(),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        intensity: _intensity,
      );

      context.read<ExerciseProvider>().addExercise(exercise);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise logged successfully!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving exercise: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Exercise'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _exerciseController,
              decoration: InputDecoration(
                labelText: 'Exercise Name (e.g., Running)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Calories Burned',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _intensity,
              items: _intensities.map((intensity) {
                return DropdownMenuItem(
                  value: intensity,
                  child: Text(intensity.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _intensity = value!;
                });
              },
              decoration: InputDecoration(
                labelText: 'Intensity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveExercise,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Save Exercise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
