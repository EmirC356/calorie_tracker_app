class DailySummary {
  final DateTime date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbohydrates;
  final double totalFat;
  final double totalFiber;
  final double caloriesBurned;
  final int exerciseCount;

  DailySummary({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbohydrates,
    required this.totalFat,
    required this.totalFiber,
    required this.caloriesBurned,
    required this.exerciseCount,
  });

  double get netCalories => totalCalories - caloriesBurned;

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.parse(json['date'] as String),
      totalCalories: (json['totalCalories'] as num).toDouble(),
      totalProtein: (json['totalProtein'] as num).toDouble(),
      totalCarbohydrates: (json['totalCarbohydrates'] as num).toDouble(),
      totalFat: (json['totalFat'] as num).toDouble(),
      totalFiber: (json['totalFiber'] as num).toDouble(),
      caloriesBurned: (json['caloriesBurned'] as num).toDouble(),
      exerciseCount: json['exerciseCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbohydrates': totalCarbohydrates,
      'totalFat': totalFat,
      'totalFiber': totalFiber,
      'caloriesBurned': caloriesBurned,
      'exerciseCount': exerciseCount,
    };
  }
}
