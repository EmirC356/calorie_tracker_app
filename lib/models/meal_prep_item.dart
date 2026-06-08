class MealPrepItem {
  final String foodName;
  final String category; // 'protein', 'carb', 'veggie'
  final double grams;

  const MealPrepItem({
    required this.foodName,
    required this.category,
    required this.grams,
  });

  Map<String, dynamic> toJson() => {
        'foodName': foodName,
        'category': category,
        'grams': grams,
      };

  factory MealPrepItem.fromJson(Map<String, dynamic> json) => MealPrepItem(
        foodName: json['foodName'] as String,
        category: json['category'] as String,
        grams: (json['grams'] as num).toDouble(),
      );
}
