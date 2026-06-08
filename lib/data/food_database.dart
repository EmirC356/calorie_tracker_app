import '../models/food_item.dart';

class FoodDatabase {
  static const List<FoodItem> proteins = [
    FoodItem(name: 'Chicken breast', calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0),
    FoodItem(name: 'Beef (lean)', calories: 215, protein: 26, carbs: 0, fat: 12, fiber: 0),
    FoodItem(name: 'Salmon', calories: 208, protein: 20, carbs: 0, fat: 13, fiber: 0),
    FoodItem(name: 'Turkey breast', calories: 135, protein: 30, carbs: 0, fat: 1, fiber: 0),
    FoodItem(name: 'Tuna (canned)', calories: 116, protein: 26, carbs: 0, fat: 0.8, fiber: 0),
    FoodItem(name: 'Eggs', calories: 155, protein: 13, carbs: 1.1, fat: 11, fiber: 0),
    FoodItem(name: 'Greek yogurt', calories: 59, protein: 10, carbs: 3.6, fat: 0.4, fiber: 0),
    FoodItem(name: 'Cottage cheese', calories: 98, protein: 11, carbs: 3.4, fat: 4.3, fiber: 0),
    FoodItem(name: 'Shrimp', calories: 99, protein: 24, carbs: 0, fat: 0.3, fiber: 0),
    FoodItem(name: 'Pork loin', calories: 242, protein: 27, carbs: 0, fat: 14, fiber: 0),
  ];

  static const List<FoodItem> carbs = [
    FoodItem(name: 'White rice (cooked)', calories: 130, protein: 2.7, carbs: 28, fat: 0.3, fiber: 0.4),
    FoodItem(name: 'Brown rice (cooked)', calories: 112, protein: 2.6, carbs: 24, fat: 0.9, fiber: 1.8),
    FoodItem(name: 'Oats (dry)', calories: 389, protein: 17, carbs: 66, fat: 7, fiber: 10.6),
    FoodItem(name: 'Sweet potato (cooked)', calories: 90, protein: 2, carbs: 21, fat: 0.1, fiber: 3.3),
    FoodItem(name: 'Potato (boiled)', calories: 87, protein: 1.9, carbs: 20, fat: 0.1, fiber: 1.8),
    FoodItem(name: 'Pasta (cooked)', calories: 131, protein: 5, carbs: 25, fat: 1.1, fiber: 1.8),
    FoodItem(name: 'Whole wheat bread', calories: 247, protein: 13, carbs: 41, fat: 3.4, fiber: 6.9),
    FoodItem(name: 'Quinoa (cooked)', calories: 120, protein: 4.4, carbs: 22, fat: 1.9, fiber: 2.8),
    FoodItem(name: 'Lentils (cooked)', calories: 116, protein: 9, carbs: 20, fat: 0.4, fiber: 7.9),
    FoodItem(name: 'Banana', calories: 89, protein: 1.1, carbs: 23, fat: 0.3, fiber: 2.6),
  ];

  static const List<FoodItem> veggies = [
    FoodItem(name: 'Broccoli', calories: 34, protein: 2.8, carbs: 7, fat: 0.4, fiber: 2.6),
    FoodItem(name: 'Spinach', calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fiber: 2.2),
    FoodItem(name: 'Mixed greens', calories: 20, protein: 2, carbs: 3, fat: 0.2, fiber: 1.5),
    FoodItem(name: 'Cucumber', calories: 16, protein: 0.7, carbs: 3.6, fat: 0.1, fiber: 0.5),
    FoodItem(name: 'Tomato', calories: 18, protein: 0.9, carbs: 3.9, fat: 0.2, fiber: 1.2),
    FoodItem(name: 'Bell pepper', calories: 31, protein: 1, carbs: 6, fat: 0.3, fiber: 2.1),
    FoodItem(name: 'Zucchini', calories: 17, protein: 1.2, carbs: 3.1, fat: 0.3, fiber: 1),
    FoodItem(name: 'Asparagus', calories: 20, protein: 2.2, carbs: 3.9, fat: 0.1, fiber: 2.1),
    FoodItem(name: 'Mushrooms', calories: 22, protein: 3.1, carbs: 3.3, fat: 0.3, fiber: 1),
    FoodItem(name: 'Green beans', calories: 31, protein: 1.8, carbs: 7, fat: 0.1, fiber: 3.4),
  ];

  // Calories and fat for oil spray amounts
  static const Map<int, ({double calories, double fat})> oilSprays = {
    3: (calories: 15, fat: 1.5),
    5: (calories: 25, fat: 2.5),
    10: (calories: 50, fat: 5.0),
    20: (calories: 100, fat: 10.0),
  };

  // Alcohol presets: (calories per unit, carbs per unit)
  static const List<({String name, double calories, double carbs})> alcoholOptions = [
    (name: 'Beer (330ml)', calories: 143, carbs: 11),
    (name: 'Light beer (330ml)', calories: 103, carbs: 5),
    (name: 'Red wine (150ml)', calories: 125, carbs: 4),
    (name: 'White wine (150ml)', calories: 121, carbs: 4),
    (name: 'Spirits / Vodka (45ml)', calories: 97, carbs: 0),
    (name: 'Whiskey (45ml)', calories: 97, carbs: 0),
  ];

  static FoodItem? findByName(String name) {
    final all = [...proteins, ...carbs, ...veggies];
    try {
      return all.firstWhere((f) => f.name == name);
    } catch (_) {
      return null;
    }
  }
}
