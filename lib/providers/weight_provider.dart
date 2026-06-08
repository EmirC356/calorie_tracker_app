import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/database_service.dart';

class WeightProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<WeightEntry> _entries = [];

  List<WeightEntry> get entries => List.unmodifiable(_entries);

  WeightEntry? get latest => _entries.isNotEmpty ? _entries.last : null;

  Future<void> loadEntries() async {
    _entries = await _db.getWeightEntries();
    notifyListeners();
  }

  Future<void> addEntry(WeightEntry entry) async {
    final id = await _db.insertWeightEntry(entry);
    _entries.add(WeightEntry(
      id: id,
      weight: entry.weight,
      timestamp: entry.timestamp,
      isEmptyStomach: entry.isEmptyStomach,
    ));
    notifyListeners();
  }

  Future<void> deleteEntry(int id) async {
    await _db.deleteWeightEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
