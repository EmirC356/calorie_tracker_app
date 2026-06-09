import '../models/index.dart';
import 'database_service.dart';

/// Local CRUD for goals, their materialized occurrences, and inbound goal
/// suggestions. All personal goal data lives in on-device SQLite (schema v5);
/// only squad-visible aggregates leave the device (Phase 6).
///
/// Occurrences are materialized lazily — the recurrence engine (Phase 2) is the
/// source of truth for which dates a goal lands on, and rows are written here
/// only when a user interacts with an occurrence or the sweep finalizes one.
class GoalService {
  final DatabaseService _db;
  GoalService({DatabaseService? db}) : _db = db ?? DatabaseService();

  // ─── Goals ──────────────────────────────────────────────────────────────────

  /// Inserts [goal] and returns its new id.
  Future<int> createGoal(Goal goal) async {
    final database = await _db.db;
    return database.insert(DatabaseService.tablesGoals, goal.toMap());
  }

  Future<void> updateGoal(Goal goal) async {
    assert(goal.id != null, 'updateGoal requires a persisted goal id');
    final database = await _db.db;
    await database.update(
      DatabaseService.tablesGoals,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Soft-archives a goal: hidden from the calendar going forward, history kept.
  Future<void> archiveGoal(int id) async {
    final database = await _db.db;
    await database.update(
      DatabaseService.tablesGoals,
      {'archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard-deletes a goal. The `ON DELETE CASCADE` foreign key removes its
  /// occurrences; we also delete them explicitly so the cascade is honored even
  /// if foreign-key enforcement is ever off in some environment.
  Future<void> deleteGoal(int id) async {
    final database = await _db.db;
    await database.delete(DatabaseService.tablesGoalOccurrences,
        where: 'goal_id = ?', whereArgs: [id]);
    await database
        .delete(DatabaseService.tablesGoals, where: 'id = ?', whereArgs: [id]);
  }

  Future<Goal?> getGoal(int id) async {
    final database = await _db.db;
    final rows = await database.query(DatabaseService.tablesGoals,
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Goal.fromMap(rows.first);
  }

  /// All goals, newest start date first. With [onlyActive], archived goals are
  /// excluded.
  Future<List<Goal>> listGoals({bool onlyActive = false}) async {
    final database = await _db.db;
    final rows = await database.query(
      DatabaseService.tablesGoals,
      where: onlyActive ? 'archived = 0' : null,
      orderBy: 'start_date DESC, id DESC',
    );
    return rows.map(Goal.fromMap).toList();
  }

  // ─── Occurrences ────────────────────────────────────────────────────────────

  /// Stored occurrence rows whose date falls in [start, end] (inclusive). Note
  /// this returns only *materialized* rows; virtual occurrences are computed by
  /// the recurrence engine in the UI layer.
  Future<List<GoalOccurrence>> getOccurrencesInRange(
      DateTime start, DateTime end) async {
    final database = await _db.db;
    final rows = await database.query(
      DatabaseService.tablesGoalOccurrences,
      where: 'occurrence_date >= ? AND occurrence_date <= ?',
      whereArgs: [ymd(start), ymd(end)],
      orderBy: 'occurrence_date ASC',
    );
    return rows.map(GoalOccurrence.fromMap).toList();
  }

  Future<List<GoalOccurrence>> getOccurrencesForGoal(int goalId) async {
    final database = await _db.db;
    final rows = await database.query(
      DatabaseService.tablesGoalOccurrences,
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'occurrence_date ASC',
    );
    return rows.map(GoalOccurrence.fromMap).toList();
  }

  Future<GoalOccurrence?> getOccurrence(int goalId, DateTime date) async {
    final database = await _db.db;
    final rows = await database.query(
      DatabaseService.tablesGoalOccurrences,
      where: 'goal_id = ? AND occurrence_date = ?',
      whereArgs: [goalId, ymd(date)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GoalOccurrence.fromMap(rows.first);
  }

  /// Inserts or updates an occurrence row keyed on (goal_id, occurrence_date).
  /// Returns the row id. Used both by the lazy materialization path and the
  /// end-of-period sweep.
  Future<int> upsertOccurrence(GoalOccurrence occ) async {
    final database = await _db.db;
    final existing = await getOccurrence(occ.goalId, occ.occurrenceDate);
    if (existing == null) {
      return database.insert(
          DatabaseService.tablesGoalOccurrences, occ.toMap());
    }
    await database.update(
      DatabaseService.tablesGoalOccurrences,
      occ.copyWith(id: existing.id).toMap(),
      where: 'id = ?',
      whereArgs: [existing.id],
    );
    return existing.id!;
  }

  /// Materialize-or-update an occurrence's status by (goalId, date). Because
  /// occurrences are lazy, the UI/sweep address them by goal + date rather than
  /// a pre-existing row id. When marking [OccurrenceStatus.done], [doneAt] is
  /// stamped (defaults to now).
  Future<int> setOccurrenceStatus({
    required int goalId,
    required DateTime date,
    required OccurrenceStatus status,
    bool override = false,
    double? periodValueCached,
    String? notes,
    DateTime? doneAt,
  }) async {
    final existing = await getOccurrence(goalId, date);
    final occ = (existing ?? GoalOccurrence(goalId: goalId, occurrenceDate: date))
        .copyWith(
      status: status,
      overrideFlag: override ? true : (existing?.overrideFlag ?? false),
      periodValueCached: periodValueCached,
      doneAt: status == OccurrenceStatus.done
          ? (doneAt ?? DateTime.now())
          : null,
      clearDoneAt: status != OccurrenceStatus.done,
      notes: notes,
    );
    return upsertOccurrence(occ);
  }

  /// Updates an existing occurrence row by its id (used by the history screen's
  /// retroactive override in Phase 5).
  Future<void> setOccurrenceStatusById(int occurrenceId, OccurrenceStatus status,
      {bool override = false}) async {
    final database = await _db.db;
    await database.update(
      DatabaseService.tablesGoalOccurrences,
      {
        'status': status.name,
        'override_flag': override ? 1 : 0,
        'done_at': status == OccurrenceStatus.done
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      },
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  // ─── Suggestions ─────────────────────────────────────────────────────────────

  Future<int> insertSuggestion(GoalSuggestion s) async {
    final database = await _db.db;
    return database.insert(DatabaseService.tablesGoalSuggestions, s.toMap());
  }

  Future<List<GoalSuggestion>> listSuggestions({SuggestionStatus? status}) async {
    final database = await _db.db;
    final rows = await database.query(
      DatabaseService.tablesGoalSuggestions,
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.name],
      orderBy: 'suggested_at DESC',
    );
    return rows.map(GoalSuggestion.fromMap).toList();
  }

  Future<List<GoalSuggestion>> pendingSuggestions() =>
      listSuggestions(status: SuggestionStatus.pending);

  Future<GoalSuggestion?> getSuggestion(int id) async {
    final database = await _db.db;
    final rows = await database.query(DatabaseService.tablesGoalSuggestions,
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return GoalSuggestion.fromMap(rows.first);
  }

  Future<void> _setSuggestionStatus(int id, SuggestionStatus status) async {
    final database = await _db.db;
    await database.update(
      DatabaseService.tablesGoalSuggestions,
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> acceptSuggestion(int id) =>
      _setSuggestionStatus(id, SuggestionStatus.accepted);

  Future<void> rejectSuggestion(int id) =>
      _setSuggestionStatus(id, SuggestionStatus.rejected);

  /// Marks every still-pending suggestion whose expiry has passed as expired.
  Future<int> expireOldSuggestions({DateTime? now}) async {
    final database = await _db.db;
    final cutoff = (now ?? DateTime.now()).toUtc().toIso8601String();
    return database.update(
      DatabaseService.tablesGoalSuggestions,
      {'status': SuggestionStatus.expired.name},
      where: 'status = ? AND expires_at < ?',
      whereArgs: [SuggestionStatus.pending.name, cutoff],
    );
  }
}
