import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/index.dart';
import '../models/goal_evaluator.dart';
import 'database_service.dart';
import 'goal_service.dart';
import 'repos/goal_repos.dart';
import 'squad_service.dart';

/// Aggregated local data for one day (from SQLite — never uploaded raw).
class DayStats {
  final double consumed;
  final double burned;
  final int exerciseMinutes;
  final List<Meal> meals;
  final List<Exercise> exercises;
  const DayStats({
    required this.consumed,
    required this.burned,
    required this.exerciseMinutes,
    required this.meals,
    required this.exercises,
  });
  static const empty = DayStats(consumed: 0, burned: 0, exerciseMinutes: 0, meals: [], exercises: []);
}

/// Aggregates the user's local day data and uploads a per-squad, sharing-level
/// redacted snapshot. Only daily aggregates leave the device.
class SnapshotService {
  late final DatabaseService _db;
  late final SquadService _squadService;
  late final GoalService _goalService;
  static const _engine = RecurrenceEngine();
  static const _evaluator = GoalEvaluator();

  SnapshotService({DatabaseService? db, SquadService? squadService, GoalService? goalService}) {
    _db = db ?? DatabaseService();
    _squadService = squadService ?? SquadService();
    // Reuse the same database instance so goal reads hit the same store.
    _goalService = goalService ?? GoalService(db: _db);
  }

  /// Local-timezone date key (a meal logged at 1am Tuesday counts as Tuesday).
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DayStats> computeStats(DateTime date) async {
    final meals = await _db.getMealsByDate(date);
    final exercises = await _db.getExercisesByDate(date);
    return DayStats(
      consumed: meals.fold(0.0, (s, m) => s + m.nutrients.calories),
      burned: exercises.fold(0.0, (s, e) => s + e.caloriesBurned),
      exerciseMinutes: exercises.fold(0, (s, e) => s + e.durationMinutes),
      meals: meals,
      exercises: exercises,
    );
  }

  /// Builds the entry document, including only the fields the [level] permits.
  /// Pure (no I/O) and static so it can be unit-tested without Firebase.
  /// [updatedAt] defaults to a server timestamp sentinel.
  static Map<String, dynamic> buildEntry({
    required GoalStatus status,
    required DayStats stats,
    required SharingLevel level,
    Object? updatedAt,
  }) {
    final map = <String, dynamic>{
      'status': status.name,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
    if (level.atLeast(SharingLevel.totals)) {
      map['consumed'] = stats.consumed;
      map['burned'] = stats.burned;
      map['exerciseMinutes'] = stats.exerciseMinutes;
    }
    if (level == SharingLevel.full) {
      map['meals'] = stats.meals
          .map((m) => {'name': m.name, 'kcal': m.nutrients.calories, 'time': m.timestamp.toIso8601String()})
          .toList();
      map['exercises'] = stats.exercises
          .map((e) => {'name': e.name, 'minutes': e.durationMinutes, 'kcal': e.caloriesBurned, 'time': e.timestamp.toIso8601String()})
          .toList();
    }
    return map;
  }

  bool _isDayOver(DateTime date, DateTime now) {
    final endOfDay = DateTime(date.year, date.month, date.day).add(const Duration(days: 1));
    return !now.isBefore(endOfDay);
  }

  /// Computes the user's [date] stats once, then writes a redacted entry to
  /// every squad they belong to (each squad's own goal + sharing level).
  Future<void> pushForUser({required String uid, DateTime? date, DateTime? now}) async {
    final theNow = now ?? DateTime.now();
    final day = date ?? theNow;
    final stats = await computeStats(day);
    final dayOver = _isDayOver(day, theNow);
    final key = dateKey(day);

    final squads = await _squadService.getMySquadsOnce(uid);
    for (final squad in squads) {
      final member = await _squadService.getMember(squad.id, uid);
      if (member == null) continue;
      final status = member.goal.evaluate(
        consumed: stats.consumed,
        exerciseMinutes: stats.exerciseMinutes,
        burned: stats.burned,
        dayOver: dayOver,
      );
      final entry = buildEntry(status: status, stats: stats, level: member.sharingLevel);
      await _squadService.writeDayEntry(squadId: squad.id, dateKey: key, uid: uid, data: entry);
    }

    // Goal visibility rides the same triggers; only run it for the "today"
    // push and never let a failure block the squad entry writes above.
    if (dateKey(day) == dateKey(theNow)) {
      try {
        await pushGoalVisibility(uid: uid, now: theNow);
      } catch (_) {/* best-effort cloud mirror */}
    }
  }

  /// Mirrors the user's **squad-visible** goal occurrences in
  /// [today−7d, today+30d] to `users/{uid}/goalsVisible/*`, and prunes docs
  /// that no longer correspond to a current occurrence (goal un-shared,
  /// archived, deleted, or out of window). Each doc carries `readerUids` (the
  /// union of memberUids across the user's squads) so squadmates can read it
  /// via an array-contains query. Writes nothing — and clears any leftovers —
  /// when the user is in no squads.
  Future<void> pushGoalVisibility({required String uid, DateTime? now}) async {
    final theNow = now ?? DateTime.now();
    final today = dateOnly(theNow);
    final from = today.subtract(const Duration(days: 7));
    final to = today.add(const Duration(days: 30));

    final squads = await _squadService.getMySquadsOnce(uid);
    final existing = await _squadService.getGoalVisibleIds(uid);

    if (squads.isEmpty) {
      for (final id in existing) {
        await _squadService.deleteGoalVisible(uid, id);
      }
      return;
    }

    final squadIds = squads.map((s) => s.id).toList();
    final readerUids = <String>{for (final s in squads) ...s.memberUids}.toList();

    final goals = (await _goalService.listGoals(onlyActive: true))
        .where((g) => g.squadVisible && g.id != null)
        .toList();

    final mealRepo = DbMealRepo(_db);
    final exerciseRepo = DbExerciseRepo(_db);
    final weightRepo = DbWeightRepo(_db);

    final desired = <String, GoalVisible>{};
    for (final g in goals) {
      for (final date in _engine.occurrencesInRange(g, from, to)) {
        final occId = '${g.id}_${dateKey(date)}';
        final row = await _goalService.getOccurrence(g.id!, date);
        String statusName;
        String? metricSummary;
        if (g.isTracked) {
          final r = await _evaluator.evaluate(
            goal: g,
            occurrenceDate: date,
            meals: mealRepo,
            exercises: exerciseRepo,
            weights: weightRepo,
            now: theNow,
          );
          // A user override (materialized row) wins over the live evaluation.
          statusName = (row?.status ?? r.status).name;
          if (r.metricValue != null && r.targetValue != null) {
            metricSummary =
                '${r.metricValue!.toStringAsFixed(0)}/${r.targetValue!.toStringAsFixed(0)} ${trackedMetricUnit(g.metric!)}';
          }
        } else {
          statusName = (row?.status ?? OccurrenceStatus.open).name;
        }
        desired[occId] = GoalVisible(
          id: occId,
          ownerUid: uid,
          goalTitle: g.title,
          category: g.categoryLabel,
          colorArgb: g.color.toARGB32(),
          priority: g.priority.name,
          date: dateKey(date),
          status: statusName,
          period: g.period?.name,
          metricSummary: metricSummary,
          squadIds: squadIds,
          readerUids: readerUids,
        );
      }
    }

    for (final gv in desired.values) {
      await _squadService.writeGoalVisible(uid, gv);
    }
    for (final id in existing) {
      if (!desired.containsKey(id)) {
        await _squadService.deleteGoalVisible(uid, id);
      }
    }
  }
}
