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
  late final DatabaseService _dbService;
  late final DbMealRepo _mealRepo;
  late final DbExerciseRepo _exerciseRepo;
  late final DbWeightRepo _weightRepo;
  late final DbWaterRepo _waterRepo;
  static const _evaluator = GoalEvaluator();

  /// Finalizes a tracked goal occurrence during the sweep. Defaults to the
  /// GoalEvaluator over the local database; tests can inject a fake.
  TrackedEvaluator? evaluateTracked;

  GoalProvider({
    DatabaseService? db,
    GoalService? service,
    RecurrenceEngine engine = const RecurrenceEngine(),
    TrackedEvaluator? evaluateTracked,
  }) : _engine = engine {
    _dbService = db ?? DatabaseService();
    // Share the single service/db instance so reads hit the same database.
    _service = service ?? GoalService(db: _dbService);
    _sweep = GoalSweepService(_service, engine: _engine);
    _mealRepo = DbMealRepo(_dbService);
    _exerciseRepo = DbExerciseRepo(_dbService);
    _weightRepo = DbWeightRepo(_dbService);
    _waterRepo = DbWaterRepo(_dbService);
    this.evaluateTracked = evaluateTracked ?? _defaultTrackedEvaluator;
  }

  /// Live tracked-goal evaluation for the detail sheet / day view (returns the
  /// full result, including the `open` in-progress state).
  Future<GoalEvaluationResult> evaluate(Goal goal, DateTime date) =>
      _evaluator.evaluate(
        goal: goal,
        occurrenceDate: date,
        meals: _mealRepo,
        exercises: _exerciseRepo,
        weights: _weightRepo,
        water: _waterRepo,
      );

  /// Wraps [evaluate] for the sweep: returns null (leave unmaterialized) when
  /// the metric can't be decided (no weight data, or water tracking off) so the
  /// sweep never records an `open` row.
  Future<GoalEvaluationResult?> _defaultTrackedEvaluator(
      Goal goal, DateTime date) async {
    final r = await evaluate(goal, date);
    return r.status == OccurrenceStatus.open ? null : r;
  }

  /// Materialized occurrence history in [from]..[to] (inclusive), joined to
  /// each occurrence's goal (including archived goals), newest first.
  Future<List<GoalHistoryEntry>> historyInRange(
      DateTime from, DateTime to) async {
    final occs = await _service.getOccurrencesInRange(from, to);
    final goals = {for (final g in await _service.listGoals()) g.id: g};
    final entries = <GoalHistoryEntry>[];
    for (final o in occs) {
      final g = goals[o.goalId];
      if (g != null) entries.add(GoalHistoryEntry(g, o));
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  /// The raw meals / exercises / weight entries logged on [date], for the Day
  /// view's Activity section (each row links to its existing edit screen).
  Future<({List<Meal> meals, List<Exercise> exercises, List<WeightEntry> weights})>
      dayDetail(DateTime date) async {
    final start = dateOnly(date);
    final end = start.add(const Duration(days: 1));
    return (
      meals: await _mealRepo.mealsInRange(start, end),
      exercises: await _exerciseRepo.exercisesInRange(start, end),
      weights: await _weightRepo.weightEntriesInRange(start, end),
    );
  }

  /// Per-day activity rollups for [from]..[to] (inclusive), keyed by
  /// `YYYY-MM-DD`, for the calendar's summary chips and Day view.
  Future<Map<String, DayActivity>> activityInRange(
      DateTime from, DateTime to) async {
    final start = dateOnly(from);
    final endExclusive = dateOnly(to).add(const Duration(days: 1));
    final meals = await _mealRepo.mealsInRange(start, endExclusive);
    final exercises = await _exerciseRepo.exercisesInRange(start, endExclusive);
    final weights = await _weightRepo.weightEntriesInRange(start, endExclusive);

    final mealCount = <String, int>{};
    final kcal = <String, double>{};
    final exCount = <String, int>{};
    final exMin = <String, int>{};
    final lastWeight = <String, double>{};

    for (final m in meals) {
      final k = ymd(m.timestamp);
      mealCount[k] = (mealCount[k] ?? 0) + 1;
      kcal[k] = (kcal[k] ?? 0) + m.nutrients.calories;
    }
    for (final e in exercises) {
      final k = ymd(e.timestamp);
      exCount[k] = (exCount[k] ?? 0) + 1;
      exMin[k] = (exMin[k] ?? 0) + e.durationMinutes;
    }
    for (final w in weights) {
      lastWeight[ymd(w.timestamp)] = w.weight; // entries are oldest-first
    }

    final keys = {...mealCount.keys, ...exCount.keys, ...lastWeight.keys};
    return {
      for (final k in keys)
        k: DayActivity(
          mealCount: mealCount[k] ?? 0,
          calories: kcal[k] ?? 0,
          exerciseCount: exCount[k] ?? 0,
          exerciseMinutes: exMin[k] ?? 0,
          hasWeight: lastWeight.containsKey(k),
          weightKg: lastWeight[k],
        ),
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

  /// Ends a recurring series the day before [date] (used by the "this and
  /// future" **delete** scope). Clamped so it never goes negative.
  Future<void> truncateSeriesBefore(Goal goal, DateTime date) async {
    final days =
        dateOnly(date).difference(dateOnly(goal.startDate)).inDays - 1;
    await _service.updateGoal(
        goal.copyWith(endDateDaysFromStart: days < 0 ? 0 : days));
    await refresh();
  }

  /// "Edit this and future": split the series at [fromDate] inclusive and apply
  /// [edited] from there onward (see [GoalService.editThisAndFuture]).
  Future<int> editThisAndFuture(Goal original, DateTime fromDate, Goal edited) async {
    final id = await _service.editThisAndFuture(
        original: original, fromDate: fromDate, edited: edited);
    await refresh();
    return id;
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

  /// Marks an occurrence done with attached proof photos (the Finish flow).
  Future<void> finishWithProof({
    required int goalId,
    required DateTime date,
    required List<Map<String, dynamic>> proofPhotoIds,
  }) async {
    await _service.setOccurrenceStatus(
      goalId: goalId, date: date, status: OccurrenceStatus.done, proofPhotoIds: proofPhotoIds);
    await refresh();
  }

  /// Reverts a proof-finished occurrence back to open and clears its proof refs
  /// (the red Undo). Deleting the actual photos is the caller's job.
  Future<void> undoFinish({required int goalId, required DateTime date}) async {
    await _service.setOccurrenceStatus(
      goalId: goalId, date: date, status: OccurrenceStatus.open, clearProof: true);
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
