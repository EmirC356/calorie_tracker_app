import 'squad_goal.dart' show CalorieMode;
import 'profile_goal_snapshot.dart';

enum Sex { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum DietGoal { cut, maintain, bulk }

/// User body metrics + goal, used to derive daily calorie and protein targets
/// via the Mifflin-St Jeor equation. Body weight is supplied at call time
/// (latest logged weight preferred), falling back to [fallbackWeightKg].
class UserProfile {
  final double heightCm;
  final int age;
  final Sex sex;
  final ActivityLevel activity;
  final DietGoal goal;
  final double? fallbackWeightKg;

  // ── Health Goals (the user's primary squad goal — see ProfileGoalSnapshot) ──
  final CalorieMode calorieGoalMode; // none | cap | floor
  final double? calorieGoalTarget; // kcal/day, when mode != none
  final int? weeklyExerciseSessions; // null/0 = no exercise goal
  final int minSessionMinutes; // a session counts at ≥ this many minutes
  final String? birthday; // ISO YYYY-MM-DD (Task 6); derives age when set
  final DateTime? healthGoalsUpdatedAt;

  const UserProfile({
    required this.heightCm,
    required this.age,
    required this.sex,
    required this.activity,
    required this.goal,
    this.fallbackWeightKg,
    this.calorieGoalMode = CalorieMode.none,
    this.calorieGoalTarget,
    this.weeklyExerciseSessions,
    this.minSessionMinutes = 20,
    this.birthday,
    this.healthGoalsUpdatedAt,
  });

  static const empty = UserProfile(
    heightCm: 0,
    age: 0,
    sex: Sex.male,
    activity: ActivityLevel.moderate,
    goal: DietGoal.maintain,
  );

  bool get isComplete => heightCm > 0 && age > 0;

  /// The Health Goals denormalized to squad member docs.
  ProfileGoalSnapshot get healthGoalSnapshot => ProfileGoalSnapshot(
        calorieMode: calorieGoalMode,
        calorieTarget: calorieGoalTarget,
        weeklyExerciseSessions: weeklyExerciseSessions,
        minSessionMinutes: minSessionMinutes,
      );

  bool get hasHealthGoal => !healthGoalSnapshot.isEmpty;

  /// Default direction for a new calorie goal: bulk floors intake, cut/maintain
  /// caps it.
  CalorieMode get suggestedCalorieMode =>
      goal == DietGoal.bulk ? CalorieMode.floor : CalorieMode.cap;

  double get activityFactor {
    switch (activity) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }

  /// Basal metabolic rate (Mifflin-St Jeor).
  double bmr(double weightKg) =>
      10 * weightKg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

  /// Total daily energy expenditure.
  double tdee(double weightKg) => bmr(weightKg) * activityFactor;

  /// Daily calorie target adjusted for the goal:
  /// cut = TDEE − 500, maintain = TDEE, bulk = TDEE + 300.
  double calorieTarget(double weightKg) {
    final t = tdee(weightKg);
    switch (goal) {
      case DietGoal.cut:
        return t - 500;
      case DietGoal.maintain:
        return t;
      case DietGoal.bulk:
        return t + 300;
    }
  }

  /// Protein grams/kg by goal (within the 0.8–2.2 g/kg range):
  /// cut = 2.2 (spare muscle in a deficit), maintain = 1.6, bulk = 2.0.
  double get proteinPerKg {
    switch (goal) {
      case DietGoal.cut:
        return 2.2;
      case DietGoal.maintain:
        return 1.6;
      case DietGoal.bulk:
        return 2.0;
    }
  }

  double proteinTargetGrams(double weightKg) => weightKg * proteinPerKg;

  UserProfile copyWith({
    double? heightCm,
    int? age,
    Sex? sex,
    ActivityLevel? activity,
    DietGoal? goal,
    double? fallbackWeightKg,
    CalorieMode? calorieGoalMode,
    double? calorieGoalTarget,
    bool clearCalorieGoalTarget = false,
    int? weeklyExerciseSessions,
    bool clearWeeklyExerciseSessions = false,
    int? minSessionMinutes,
    String? birthday,
    bool clearBirthday = false,
    DateTime? healthGoalsUpdatedAt,
  }) {
    return UserProfile(
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
      fallbackWeightKg: fallbackWeightKg ?? this.fallbackWeightKg,
      calorieGoalMode: calorieGoalMode ?? this.calorieGoalMode,
      calorieGoalTarget:
          clearCalorieGoalTarget ? null : (calorieGoalTarget ?? this.calorieGoalTarget),
      weeklyExerciseSessions: clearWeeklyExerciseSessions
          ? null
          : (weeklyExerciseSessions ?? this.weeklyExerciseSessions),
      minSessionMinutes: minSessionMinutes ?? this.minSessionMinutes,
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
      healthGoalsUpdatedAt: healthGoalsUpdatedAt ?? this.healthGoalsUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'heightCm': heightCm,
        'age': age,
        'sex': sex.name,
        'activity': activity.name,
        'goal': goal.name,
        'fallbackWeightKg': fallbackWeightKg,
        'calorieGoalMode': calorieGoalMode.name,
        'calorieGoalTarget': calorieGoalTarget,
        'weeklyExerciseSessions': weeklyExerciseSessions,
        'minSessionMinutes': minSessionMinutes,
        'birthday': birthday,
        'healthGoalsUpdatedAt': healthGoalsUpdatedAt?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
        age: (json['age'] as num?)?.toInt() ?? 0,
        sex: Sex.values.byName(json['sex'] as String? ?? 'male'),
        activity:
            ActivityLevel.values.byName(json['activity'] as String? ?? 'moderate'),
        goal: DietGoal.values.byName(json['goal'] as String? ?? 'maintain'),
        fallbackWeightKg: (json['fallbackWeightKg'] as num?)?.toDouble(),
        calorieGoalMode:
            CalorieMode.values.byName(json['calorieGoalMode'] as String? ?? 'none'),
        calorieGoalTarget: (json['calorieGoalTarget'] as num?)?.toDouble(),
        weeklyExerciseSessions: (json['weeklyExerciseSessions'] as num?)?.toInt(),
        minSessionMinutes: (json['minSessionMinutes'] as num?)?.toInt() ?? 20,
        birthday: json['birthday'] as String?,
        healthGoalsUpdatedAt: json['healthGoalsUpdatedAt'] != null
            ? DateTime.tryParse(json['healthGoalsUpdatedAt'] as String)
            : null,
      );
}
