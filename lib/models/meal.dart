import 'nutrient.dart';

class Meal {
  final int? id;
  final String name;
  final double portionGrams; // portion size in grams (0 = unspecified)
  final NutrientInfo nutrients;
  final DateTime timestamp;
  final String? notes;

  /// When set (YYYY-MM-DD), this entry is a make-up recovering that missed squad
  /// day rather than (only) counting toward its own day.
  final String? makeupForDate;

  Meal({
    this.id,
    required this.name,
    required this.portionGrams,
    required this.nutrients,
    required this.timestamp,
    this.notes,
    this.makeupForDate,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] as int?,
      name: json['name'] as String,
      // Accept the legacy 'weight' key so old exports still import.
      portionGrams:
          ((json['portionGrams'] ?? json['weight']) as num?)?.toDouble() ?? 0,
      nutrients: NutrientInfo.fromJson(json['nutrients']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String?,
      makeupForDate: (json['makeupForDate'] ?? json['makeup_for_date']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'portionGrams': portionGrams,
      'nutrients': nutrients.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'makeupForDate': makeupForDate,
    };
  }
}
