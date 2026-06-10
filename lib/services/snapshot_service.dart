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

  /// The day-entry build pipeline. Each feature adds a transformer here rather
  /// than editing the core write. Order matters — a transformer that returns
  /// false (e.g. a paused day) finalizes the entry and skips the rest.
  late final List<SnapshotTransformer> transformers;

  SnapshotService({
    DatabaseService? db,
    SquadService? squadService,
    GoalService? goalService,
    List<SnapshotTransformer>? transformers,
  }) {
    _db = db ?? DatabaseService();
    _squadService = squadService ?? SquadService();
    // Reuse the same database instance so goal reads hit the same store.
    _goalService = goalService ?? GoalService(db: _db);
    // Pause is the first gate: a paused day finalizes as `paused` and skips the
    // rest of the pipeline (status, totals, group-goal contributions).
    this.transformers = transformers ?? const [PauseTransformer(), StatusTransformer()];
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
      final ctx = SnapshotContext(
        uid: uid,
        squad: squad,
        member: member,
        date: day,
        dateKey: key,
        now: theNow,
        dayOver: dayOver,
        stats: stats,
        db: _db,
        squadService: _squadService,
      );
      final entry = <String, dynamic>{};
      for (final t in transformers) {
        if (!await t.apply(ctx, entry)) break; // a transformer can finalize early
      }
      await _squadService.writeDayEntry(squadId: squad.id, dateKey: key, uid: uid, data: entry);
    }

    // Goal visibility rides the same triggers; only run it for the "today"
    // push and never let a failure block the squad entry writes above.
    if (dateKey(day) == dateKey(theNow)) {
      try {
        await pushGoalVisibility(uid: uid, now: theNow);
      } catch (_) {/* best-effort cloud mirror */}
      try {
        await writeGoalNotifQueue(uid: uid, now: theNow);
      } catch (_) {/* best-effort notification queue */}
    }
  }

  /// Writes the device-side notification queue the Cloud Functions read:
  ///  - `users/{uid}/todaysGoalsBrief/{today}`: the goals to mention in the 8am
  ///    brief (those with morningBriefIncluded), as { goalsCount, items, … }.
  ///  - `users/{uid}/pendingReminders/{goalId}_{today}`: one doc per today's
  ///    occurrence with a reminder + time whose fire time is still in the future
  ///    (fireAt = time − reminderMinutesBefore). Stale reminder docs are pruned.
  ///
  /// Functions can't read local SQLite, so the device computes these from its
  /// goals and Firestore acts as a queue.
  Future<void> writeGoalNotifQueue({required String uid, DateTime? now}) async {
    final theNow = now ?? DateTime.now();
    final today = dateOnly(theNow);
    final key = dateKey(today);

    final goals = (await _goalService.listGoals(onlyActive: true))
        .where((g) => g.id != null)
        .toList();

    // Morning brief.
    final items = <Map<String, dynamic>>[];
    for (final g in goals.where((g) => g.morningBriefIncluded)) {
      if (_engine.occursOn(g, today)) {
        items.add({
          'title': g.title,
          if (g.timeOfDay != null)
            'time': '${g.timeOfDay!.hour.toString().padLeft(2, '0')}:${g.timeOfDay!.minute.toString().padLeft(2, '0')}',
        });
      }
    }
    await _squadService.writeTodaysBrief(uid, key, {
      'goalsCount': items.length,
      'items': items,
      'generatedAt': FieldValue.serverTimestamp(),
    });

    // Reminders for today's timed occurrences whose fire time is still ahead.
    final desired = <String>{};
    for (final g in goals) {
      if (g.reminderMinutesBefore == null || g.timeOfDay == null) continue;
      if (!_engine.occursOn(g, today)) continue;
      final at = DateTime(today.year, today.month, today.day, g.timeOfDay!.hour, g.timeOfDay!.minute)
          .subtract(Duration(minutes: g.reminderMinutesBefore!));
      if (!at.isAfter(theNow)) continue; // already passed today
      final occId = '${g.id}_$key';
      desired.add(occId);
      await _squadService.writePendingReminder(uid, occId, {
        'fireAt': at.toUtc().toIso8601String(),
        'title': g.title,
      });
    }
    // Prune reminder docs that no longer apply (today's set only; the function
    // deletes fired ones, so leftovers here are changed/removed goals).
    for (final id in await _squadService.getPendingReminderIds(uid)) {
      if (id.endsWith('_$key') && !desired.contains(id)) {
        await _squadService.deletePendingReminder(uid, id);
      }
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
    final waterRepo = DbWaterRepo(_db);

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
            water: waterRepo,
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

/// Shared, read-only context handed to every [SnapshotTransformer] for one
/// squad day-entry.
class SnapshotContext {
  final String uid;
  final Squad squad;
  final SquadMember member;
  final DateTime date; // the day being written (raw)
  final String dateKey; // YYYY-MM-DD local key
  final DateTime now;
  final bool dayOver;
  final DayStats stats;
  final DatabaseService db;
  final SquadService squadService;

  const SnapshotContext({
    required this.uid,
    required this.squad,
    required this.member,
    required this.date,
    required this.dateKey,
    required this.now,
    required this.dayOver,
    required this.stats,
    required this.db,
    required this.squadService,
  });
}

/// A composable step in the snapshot write pipeline. It mutates [entry] (and may
/// have side effects, e.g. incrementing a group goal). Return `false` to
/// finalize the entry as-is and skip the remaining transformers — a paused day
/// short-circuits this way.
abstract class SnapshotTransformer {
  const SnapshotTransformer();
  Future<bool> apply(SnapshotContext ctx, Map<String, dynamic> entry);
}

/// First gate: if the member is paused on this day, write `{status:'paused',
/// paused:true}` and finalize — no streak break, no ghosting, no contributions.
class PauseTransformer extends SnapshotTransformer {
  const PauseTransformer();

  @override
  Future<bool> apply(SnapshotContext ctx, Map<String, dynamic> entry) async {
    if (ctx.member.pause.isPausedOn(ctx.date)) {
      entry['status'] = 'paused';
      entry['paused'] = true;
      entry['updatedAt'] = FieldValue.serverTimestamp();
      return false; // finalize — skip status/totals/contributions
    }
    return true;
  }
}

/// Base transformer: the member's goal status + sharing-level-redacted totals.
/// (Mirrors [SnapshotService.buildEntry], which stays a pure unit-tested fn.)
class StatusTransformer extends SnapshotTransformer {
  const StatusTransformer();

  @override
  Future<bool> apply(SnapshotContext ctx, Map<String, dynamic> entry) async {
    final status = ctx.member.goal.evaluate(
      consumed: ctx.stats.consumed,
      exerciseMinutes: ctx.stats.exerciseMinutes,
      burned: ctx.stats.burned,
      dayOver: ctx.dayOver,
    );
    entry.addAll(SnapshotService.buildEntry(
      status: status,
      stats: ctx.stats,
      level: ctx.member.sharingLevel,
    ));
    return true;
  }
}
