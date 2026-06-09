/// How the calorie sub-goal is interpreted.
enum CalorieMode { cap, floor, none }

/// Daily goal outcome for a member.
enum GoalStatus { hit, inProgress, missed }

/// A member's per-squad daily goal. Any subset of sub-goals can be active, but
/// an "empty" goal (no active sub-goal) is invalid. Always visible to
/// squadmates — only meal/exercise *details* are gated by sharing level.
class SquadGoal {
  final CalorieMode calorieMode;
  final int? calorieTarget; // kcal; required when calorieMode != none
  final int? exerciseMinutesMin; // minutes
  final int? caloriesBurnedMin; // kcal

  const SquadGoal({
    this.calorieMode = CalorieMode.none,
    this.calorieTarget,
    this.exerciseMinutesMin,
    this.caloriesBurnedMin,
  });

  bool get calorieActive => calorieMode != CalorieMode.none && calorieTarget != null;

  /// At least one active sub-goal (a calorie cap/floor with a target, a minimum
  /// exercise duration, or a minimum calories-burned).
  bool get isValid =>
      calorieActive || exerciseMinutesMin != null || caloriesBurnedMin != null;

  bool get isEmpty => !isValid;

  /// Evaluates the day's stats against the active sub-goals.
  /// 'hit' = all active sub-goals satisfied; 'inProgress' = day not over and
  /// not all satisfied; 'missed' = day over and not all satisfied. An empty
  /// (unset) goal can never be "hit".
  GoalStatus evaluate({
    required double consumed,
    required int exerciseMinutes,
    required double burned,
    required bool dayOver,
  }) {
    if (isEmpty) return dayOver ? GoalStatus.missed : GoalStatus.inProgress;
    var pass = true;
    if (calorieActive) {
      if (calorieMode == CalorieMode.cap) pass = pass && consumed <= calorieTarget!;
      if (calorieMode == CalorieMode.floor) pass = pass && consumed >= calorieTarget!;
    }
    if (exerciseMinutesMin != null) pass = pass && exerciseMinutes >= exerciseMinutesMin!;
    if (caloriesBurnedMin != null) pass = pass && burned >= caloriesBurnedMin!;
    if (pass) return GoalStatus.hit;
    return dayOver ? GoalStatus.missed : GoalStatus.inProgress;
  }

  /// Compact human-readable goal, e.g. "≤ 2200 kcal & ≥ 30 min". Always
  /// visible to squadmates regardless of sharing level.
  String get summary {
    final parts = <String>[];
    if (calorieActive) {
      parts.add('${calorieMode == CalorieMode.cap ? '≤' : '≥'} $calorieTarget kcal');
    }
    if (exerciseMinutesMin != null) parts.add('≥ $exerciseMinutesMin min');
    if (caloriesBurnedMin != null) parts.add('≥ $caloriesBurnedMin kcal burned');
    return parts.isEmpty ? 'No goal set' : parts.join(' & ');
  }

  Map<String, dynamic> toMap() => {
        'calorieMode': calorieMode.name,
        'calorieTarget': calorieTarget,
        'exerciseMinutesMin': exerciseMinutesMin,
        'caloriesBurnedMin': caloriesBurnedMin,
      };

  factory SquadGoal.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SquadGoal();
    return SquadGoal(
      calorieMode: CalorieMode.values.byName((map['calorieMode'] as String?) ?? 'none'),
      calorieTarget: (map['calorieTarget'] as num?)?.toInt(),
      exerciseMinutesMin: (map['exerciseMinutesMin'] as num?)?.toInt(),
      caloriesBurnedMin: (map['caloriesBurnedMin'] as num?)?.toInt(),
    );
  }

  SquadGoal copyWith({
    CalorieMode? calorieMode,
    int? calorieTarget,
    int? exerciseMinutesMin,
    int? caloriesBurnedMin,
    bool clearCalorieTarget = false,
    bool clearExercise = false,
    bool clearBurned = false,
  }) =>
      SquadGoal(
        calorieMode: calorieMode ?? this.calorieMode,
        calorieTarget: clearCalorieTarget ? null : (calorieTarget ?? this.calorieTarget),
        exerciseMinutesMin: clearExercise ? null : (exerciseMinutesMin ?? this.exerciseMinutesMin),
        caloriesBurnedMin: clearBurned ? null : (caloriesBurnedMin ?? this.caloriesBurnedMin),
      );
}
