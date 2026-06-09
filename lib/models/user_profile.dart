enum Sex { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { cut, maintain, bulk }

/// User body metrics + goal, used to derive daily calorie and protein targets
/// via the Mifflin-St Jeor equation. Body weight is supplied at call time
/// (latest logged weight preferred), falling back to [fallbackWeightKg].
class UserProfile {
  final double heightCm;
  final int age;
  final Sex sex;
  final ActivityLevel activity;
  final Goal goal;
  final double? fallbackWeightKg;

  const UserProfile({
    required this.heightCm,
    required this.age,
    required this.sex,
    required this.activity,
    required this.goal,
    this.fallbackWeightKg,
  });

  static const empty = UserProfile(
    heightCm: 0,
    age: 0,
    sex: Sex.male,
    activity: ActivityLevel.moderate,
    goal: Goal.maintain,
  );

  bool get isComplete => heightCm > 0 && age > 0;

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
      case Goal.cut:
        return t - 500;
      case Goal.maintain:
        return t;
      case Goal.bulk:
        return t + 300;
    }
  }

  /// Protein grams/kg by goal (within the 0.8–2.2 g/kg range):
  /// cut = 2.2 (spare muscle in a deficit), maintain = 1.6, bulk = 2.0.
  double get proteinPerKg {
    switch (goal) {
      case Goal.cut:
        return 2.2;
      case Goal.maintain:
        return 1.6;
      case Goal.bulk:
        return 2.0;
    }
  }

  double proteinTargetGrams(double weightKg) => weightKg * proteinPerKg;

  UserProfile copyWith({
    double? heightCm,
    int? age,
    Sex? sex,
    ActivityLevel? activity,
    Goal? goal,
    double? fallbackWeightKg,
  }) {
    return UserProfile(
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
      fallbackWeightKg: fallbackWeightKg ?? this.fallbackWeightKg,
    );
  }

  Map<String, dynamic> toJson() => {
        'heightCm': heightCm,
        'age': age,
        'sex': sex.name,
        'activity': activity.name,
        'goal': goal.name,
        'fallbackWeightKg': fallbackWeightKg,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
        age: (json['age'] as num?)?.toInt() ?? 0,
        sex: Sex.values.byName(json['sex'] as String? ?? 'male'),
        activity:
            ActivityLevel.values.byName(json['activity'] as String? ?? 'moderate'),
        goal: Goal.values.byName(json['goal'] as String? ?? 'maintain'),
        fallbackWeightKg: (json['fallbackWeightKg'] as num?)?.toDouble(),
      );
}
