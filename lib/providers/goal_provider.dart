import 'package:flutter/foundation.dart';
import '../models/index.dart';
import '../services/goal_service.dart';

/// Bridges [GoalService] to the Calendar UI. Loads lazily on first access (like
/// the squad providers) so it never does IO until the Calendar tab is opened.
///
/// In Phase 1 the occurrence lists reflect only *materialized* rows; the
/// recurrence engine (Phase 2) fills in the virtual occurrences the calendar
/// renders. The provider is intentionally thin here and grows in later phases.
class GoalProvider extends ChangeNotifier {
  final GoalService _service;
  GoalProvider({GoalService? service}) : _service = service ?? GoalService();

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<Goal> _goals = [];
  List<GoalOccurrence> _todaysOccurrences = [];
  List<GoalOccurrence> _weeksOccurrences = [];
  int _pendingSuggestions = 0;

  List<Goal> get goals => List.unmodifiable(_goals);
  List<Goal> get activeGoals =>
      _goals.where((g) => !g.archived).toList(growable: false);
  List<GoalOccurrence> get todaysOccurrences =>
      List.unmodifiable(_todaysOccurrences);
  List<GoalOccurrence> get weeksOccurrences =>
      List.unmodifiable(_weeksOccurrences);
  int get pendingSuggestionsCount => _pendingSuggestions;

  GoalService get service => _service;

  /// Loads everything on first access; subsequent calls are no-ops unless
  /// [force] is set.
  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    await refresh();
  }

  Future<void> refresh() async {
    _goals = await _service.listGoals();
    await _loadOccurrenceWindows();
    await _service.expireOldSuggestions();
    _pendingSuggestions = (await _service.pendingSuggestions()).length;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadOccurrenceWindows({DateTime? now}) async {
    final ref = dateOnly(now ?? DateTime.now());
    _todaysOccurrences = await _service.getOccurrencesInRange(ref, ref);
    _weeksOccurrences =
        await _service.getOccurrencesInRange(mondayOf(ref), sundayOf(ref));
  }

  // ─── Goal mutations ──────────────────────────────────────────────────────────

  Future<int> createGoal(Goal goal) async {
    final id = await _service.createGoal(goal);
    await refresh();
    return id;
  }

  Future<void> updateGoal(Goal goal) async {
    await _service.updateGoal(goal);
    await refresh();
  }

  Future<void> archiveGoal(int id) async {
    await _service.archiveGoal(id);
    await refresh();
  }

  Future<void> deleteGoal(int id) async {
    await _service.deleteGoal(id);
    await refresh();
  }

  Future<void> setOccurrenceStatus({
    required int goalId,
    required DateTime date,
    required OccurrenceStatus status,
    bool override = false,
    double? periodValueCached,
  }) async {
    await _service.setOccurrenceStatus(
      goalId: goalId,
      date: date,
      status: status,
      override: override,
      periodValueCached: periodValueCached,
    );
    await refresh();
  }

  // ─── Suggestions ─────────────────────────────────────────────────────────────

  Future<List<GoalSuggestion>> pendingSuggestions() =>
      _service.pendingSuggestions();

  Future<void> rejectSuggestion(int id) async {
    await _service.rejectSuggestion(id);
    await refresh();
  }
}
