import 'package:flutter/foundation.dart';
import '../models/index.dart';
import '../services/database_service.dart';

/// Tracks daily water intake (millilitres). Local-only, like the other trackers.
class WaterProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<WaterEntry> _today = [];
  List<WaterEntry> get todaysEntries => List.unmodifiable(_today);
  int get todaysTotalMl => _today.fold(0, (s, e) => s + e.amountMl);

  Future<void> loadToday() async {
    _today = await _dbService.getWaterEntriesByDate(DateTime.now());
    notifyListeners();
  }

  Future<void> add(int ml) async {
    await _dbService.insertWaterEntry(WaterEntry(amountMl: ml, timestamp: DateTime.now()));
    await loadToday();
  }

  /// Removes the most recent entry (the dashboard "undo last" affordance).
  Future<void> removeLast() async {
    if (_today.isEmpty) return;
    final last = _today.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
    if (last.id != null) {
      await _dbService.deleteWaterEntry(last.id!);
      await loadToday();
    }
  }
}
