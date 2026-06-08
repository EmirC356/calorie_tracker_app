import 'nutrient.dart';

class Meal {
  final int? id;
  final String name;
  final double weight; // in grams
  final NutrientInfo nutrients;
  final DateTime timestamp;
  final String? notes;

  Meal({
    this.id,
    required this.name,
    required this.weight,
    required this.nutrients,
    required this.timestamp,
    this.notes,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] as int?,
      name: json['name'] as String,
      weight: (json['weight'] as num).toDouble(),
      nutrients: NutrientInfo.fromJson(json['nutrients']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'nutrients': nutrients.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }
}
