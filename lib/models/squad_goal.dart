/// How the calorie sub-goal is interpreted.
enum CalorieMode { cap, floor, none }

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
