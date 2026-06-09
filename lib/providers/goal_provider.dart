import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/index.dart';
import '../models/goal_evaluator.dart';
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../services/goal_sweep_service.dart';
import '../services/repos/goal_repos.dart';
import '../services/prefs.dart';

/// Bridges [GoalService] to the Calendar UI. Loads lazily on first access (like
/// the squad providers) so it never does IO until the Calendar tab is opened.
///
/// The recurrence engine is the source of truth for *which* dates a goal lands
/// on; [GoalOccurrence] rows are only the materialized (interacted-with or
/// swept) instances. UI surfaces should overlay the two via
/// [statusFor]/[occurrencesOn].
class GoalProvider extends ChangeNotifier {
  late final GoalService _service;
  final RecurrenceEngine _engine;
  late final GoalSweepService _sweep;

  /// Finalizes a tracked goal occurrence during the sweep. Defaults to the
  /// GoalEvaluator over the local database; tests can inject a fake.
  TrackedEvaluator? evaluateTracked;

  GoalProvider({
    DatabaseService? db,
    GoalService? service,
    RecurrenceEngine engine = const RecurrenceEngine(),
    TrackedEvaluator? evaluateTracked,
  }) : _engine = engine {
    final dbService = db ?? DatabaseService();
    // Share the single service/db instance so reads hit the same database.
    _service = service ?? GoalService(db: dbService);
    _sweep = GoalSweepService(_service, engine: _engine);
    this.evaluateTracked =
        evaluateTracked ?? _defaultTrackedEvaluator(dbService);
  }

  /// Wires the GoalEvaluator over the local DB. Returns null (leave
  /// unmaterialized) when the metric can't be decided (e.g. no weight data, or
  /// water tracking not enabled) so the sweep never records an `open` row.
  TrackedEvaluator _defaultTrackedEvaluator(DatabaseService dbService) {
    const evaluator = GoalEvaluator();
    final meals = DbMealRepo(dbService);
    final exercises = DbExerciseRepo(dbService);
    final weights = DbWeightRepo(dbService);
    return (goal, date) async {
      final r = await evaluator.evaluate(
        goal: goal,
        occurrenceDate: date,
        meals: meals,
        exercises: exercises,
        weights: weights,
        water: null,
      );
      return r.status == OccurrenceStatus.open ? null : r;
    };
  }

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<Goal> _goals = [];
  // Materialized rows in the current month/week window, keyed by
  // "{goalId}_{YYYY-MM-DD}" for O(1) overlay lookups.
  final Map<String, GoalOccurrence> _rows = {};
  int _pendingSuggestions = 0;

  List<Goal> get goals => List.unmodifiable(_goals);
  List<Goal> get activeGoals =>
      _goals.where((g) => !g.archived).toList(growable: false);
  int get pendingSuggestionsCount => _pendingSuggestions;

  GoalService get service => _service;
  RecurrenceEngine get engine => _engine;

  String _key(int goalId, DateTime date) => '${goalId}_${ymd(date)}';

  /// The materialized status for a goal on a date, or `open` if no row exists
  /// (the engine says it occurs but nothing's been recorded/swept yet).
  GoalOccurrence? rowFor(int goalId, DateTime date) =>
      _rows[_key(goalId, date)];

  // ─── Loading ────────────────────────────────────────────────────────────────

  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    await runSweep(); // finalize past occurrences, then load
  }

  Future<void> refresh() async {
    _goals = await _service.listGoals();
    await _loadRowsWindow();
    await _service.expireOldSuggestions();
    _pendingSuggestions = (await _service.pendingSuggestions()).length;
    _loaded = true;
    notifyListeners();
  }

  /// Loads materialized occurrence rows for a generous window around today
  /// (this month ± a month) into [_rows] for fast overlay lookups.
  Future<void> _loadRowsWindow({DateTime? now}) async {
    final ref = dateOnly(now ?? DateTime.now());
    final from = DateTime(ref.year, ref.month - 1, 1);
    final to = DateTime(ref.year, ref.month + 2, 0);
    final rows = await _service.getOccurrencesInRange(from, to);
    _rows
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(_key(r.goalId, r.occurrenceDate), r)));
  }

  /// Runs the end-of-period sweep (bounded by the persisted last-sweep date),
  /// then reloads. Safe to call repeatedly — the sweep is idempotent.
  Future<void> runSweep({DateTime? now}) async {
    final ref = now ?? DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastStr = prefs.getString(kLastGoalSweepPref);
      final since = lastStr == null ? null : parseYmd(lastStr);
      await _sweep.sweepFinalizePastOccurrences(
        asOf: ref,
        since: since,
        evaluateTracked: evaluateTracked,
      );
      await prefs.setString(kLastGoalSweepPref, ymd(dateOnly(ref)));
    } catch (e) {
      debugPrint('Goal sweep skipped: $e');
    }
    await refresh();
  }

  // ─── Occurrence overlay (engine + rows) ──────────────────────────────────────

  /// Active goals that occur on [date] (engine-driven), each paired with its
  /// materialized row if one exists.
  List<({Goal goal, GoalOccurrence? row})> occurrencesOn(DateTime date) {
    final out = <({Goal goal, GoalOccurrence? row})>[];
    for (final g in activeGoals) {
      if (g.id != null && _engine.occursOn(g, date)) {
        out.add((goal: g, row: rowFor(g.id!, date)));
      }
    }
    return out;
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
