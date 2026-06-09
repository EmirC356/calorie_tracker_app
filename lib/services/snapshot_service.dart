import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/index.dart';
import 'database_service.dart';
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
  final DatabaseService _db;
  final SquadService _squadService;

  SnapshotService({DatabaseService? db, SquadService? squadService})
      : _db = db ?? DatabaseService(),
        _squadService = squadService ?? SquadService();

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
  }
}
