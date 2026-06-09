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
  final double? consumed; // totals+
  final double? burned;
  final int? exerciseMinutes;
  final List<EntryMeal>? meals; // full only
  final List<EntryExercise>? exercises;
  final DateTime? updatedAt;

  const SquadDayEntry({
    required this.uid,
    required this.status,
    this.consumed,
    this.burned,
    this.exerciseMinutes,
    this.meals,
    this.exercises,
    this.updatedAt,
  });

  bool get hasTotals => consumed != null || burned != null || exerciseMinutes != null;
  bool get hasDetails => meals != null || exercises != null;

  factory SquadDayEntry.fromMap(String uid, Map<String, dynamic> m) => SquadDayEntry(
        uid: uid,
        status: GoalStatus.values.byName((m['status'] as String?) ?? 'inProgress'),
        consumed: (m['consumed'] as num?)?.toDouble(),
        burned: (m['burned'] as num?)?.toDouble(),
        exerciseMinutes: (m['exerciseMinutes'] as num?)?.toInt(),
        meals: (m['meals'] as List?)?.map((e) => EntryMeal.fromMap(Map<String, dynamic>.from(e))).toList(),
        exercises: (m['exercises'] as List?)?.map((e) => EntryExercise.fromMap(Map<String, dynamic>.from(e))).toList(),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      );
}
