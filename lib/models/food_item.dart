class FoodItem {
  final String name;
  final double calories; // per 100g
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });
}
