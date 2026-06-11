import 'squad_goal.dart';

/// The user's profile-level Health Goals, denormalized onto each squad member
/// doc (`profileGoalSnapshot`) so squadmates can read the goal definition and
/// the daily evaluator can resolve an effective [SquadGoal].
///
/// The calorie goal is a daily cap/floor. The exercise goal is *weekly* (N
/// sessions, each ≥ [minSessionMinutes]); for the daily snapshot it resolves to
/// a daily "log one qualifying session" minimum — see [toDailyGoal].
class ProfileGoalSnapshot {
  final CalorieMode calorieMode;
  final double? calorieTarget; // kcal/day
  final int? weeklyExerciseSessions; // null/0 = no exercise goal
  final int minSessionMinutes;

  const ProfileGoalSnapshot({
    this.calorieMode = CalorieMode.none,
    this.calorieTarget,
    this.weeklyExerciseSessions,
    this.minSessionMinutes = 20,
  });

  bool get hasCalorieGoal => calorieMode != CalorieMode.none && calorieTarget != null;
  bool get hasExerciseGoal => (weeklyExerciseSessions ?? 0) > 0;
  bool get isEmpty => !hasCalorieGoal && !hasExerciseGoal;

  /// Daily-evaluable goal: the calorie cap/floor, plus a daily exercise minimum
  /// of [minSessionMinutes] when a weekly-sessions goal is set (so a qualifying
  /// session logged that day satisfies the day's exercise sub-goal).
  SquadGoal toDailyGoal() => SquadGoal(
        calorieMode: hasCalorieGoal ? calorieMode : CalorieMode.none,
        calorieTarget: hasCalorieGoal ? calorieTarget!.round() : null,
        exerciseMinutesMin: hasExerciseGoal ? minSessionMinutes : null,
      );

  /// "≤ 2200 kcal/day" / "≥ 2800 kcal/day", or null when no calorie goal.
  String? get calorieSummary => hasCalorieGoal
      ? '${calorieMode == CalorieMode.cap ? '≤' : '≥'} ${calorieTarget!.round()} kcal/day'
      : null;

  /// "3 sessions/week (≥ 20 min)", or null when no exercise goal.
  String? get exerciseSummary => hasExerciseGoal
      ? '$weeklyExerciseSessions session${weeklyExerciseSessions == 1 ? '' : 's'}/week '
          '(≥ $minSessionMinutes min)'
      : null;

  Map<String, dynamic> toMap() => {
        'calorieMode': calorieMode.name,
        'calorieTarget': calorieTarget,
        'weeklyExerciseSessions': weeklyExerciseSessions,
        'minSessionMinutes': minSessionMinutes,
      };

  factory ProfileGoalSnapshot.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ProfileGoalSnapshot();
    return ProfileGoalSnapshot(
      calorieMode: CalorieMode.values.byName((m['calorieMode'] as String?) ?? 'none'),
      calorieTarget: (m['calorieTarget'] as num?)?.toDouble(),
      weeklyExerciseSessions: (m['weeklyExerciseSessions'] as num?)?.toInt(),
      minSessionMinutes: (m['minSessionMinutes'] as num?)?.toInt() ?? 20,
    );
  }
}
