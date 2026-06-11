import 'package:cloud_firestore/cloud_firestore.dart';
import 'squad_goal.dart';

/// A single item inside a 'full'-sharing day entry.
class EntryMeal {
  final String name;
  final double kcal;
  final DateTime? time;
  const EntryMeal({required this.name, required this.kcal, this.time});

  Map<String, dynamic> toMap() => {'name': name, 'kcal': kcal, 'time': time?.toIso8601String()};
  factory EntryMeal.fromMap(Map<String, dynamic> m) => EntryMeal(
        name: (m['name'] as String?) ?? '',
        kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
        time: m['time'] != null ? DateTime.tryParse(m['time'] as String) : null,
      );
}

class EntryExercise {
  final String name;
  final int minutes;
  final double kcal;
  final DateTime? time;
  const EntryExercise({required this.name, required this.minutes, required this.kcal, this.time});

  Map<String, dynamic> toMap() =>
      {'name': name, 'minutes': minutes, 'kcal': kcal, 'time': time?.toIso8601String()};
  factory EntryExercise.fromMap(Map<String, dynamic> m) => EntryExercise(
        name: (m['name'] as String?) ?? '',
        minutes: (m['minutes'] as num?)?.toInt() ?? 0,
        kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
        time: m['time'] != null ? DateTime.tryParse(m['time'] as String) : null,
      );
}

/// squads/{squadId}/days/{YYYY-MM-DD}/entries/{uid}. Fields beyond `status`
/// appear only when the member's sharing level allows (totals / full).
class SquadDayEntry {
  final String uid;
  final GoalStatus status;
  final bool paused; // a paused (vacation) day — status falls back to inProgress
  final bool redeemed; // a missed day rescued by a make-up (counts 0.5)
  final String? makeupForDate; // set on a make-up day's entry → the day it recovers
  final double? consumed; // totals+
  final double? burned;
  final int? exerciseMinutes;
  final List<EntryMeal>? meals; // full only
  final List<EntryExercise>? exercises;
  final DateTime? updatedAt;

  const SquadDayEntry({
    required this.uid,
    required this.status,
    this.paused = false,
    this.redeemed = false,
    this.makeupForDate,
    this.consumed,
    this.burned,
    this.exerciseMinutes,
    this.meals,
    this.exercises,
    this.updatedAt,
  });

  bool get hasTotals => consumed != null || burned != null || exerciseMinutes != null;
  bool get hasDetails => meals != null || exercises != null;

  factory SquadDayEntry.fromMap(String uid, Map<String, dynamic> m) {
    final statusName = (m['status'] as String?) ?? 'inProgress';
    final paused = (m['paused'] as bool?) ?? (statusName == 'paused');
    return SquadDayEntry(
      uid: uid,
      // 'paused' isn't a GoalStatus — fall back to inProgress and use [paused].
      status: GoalStatus.values.asNameMap()[statusName] ?? GoalStatus.inProgress,
      paused: paused,
      redeemed: (m['redeemed'] as bool?) ?? false,
      makeupForDate: m['makeupForDate'] as String?,
      consumed: (m['consumed'] as num?)?.toDouble(),
      burned: (m['burned'] as num?)?.toDouble(),
      exerciseMinutes: (m['exerciseMinutes'] as num?)?.toInt(),
      meals: (m['meals'] as List?)?.map((e) => EntryMeal.fromMap(Map<String, dynamic>.from(e))).toList(),
      exercises: (m['exercises'] as List?)?.map((e) => EntryExercise.fromMap(Map<String, dynamic>.from(e))).toList(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
