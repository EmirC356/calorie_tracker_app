import 'dart:convert';
import 'nutrient.dart';
import 'meal_prep_item.dart';

class MealPrep {
  final int? id;
  final String name;
  final List<MealPrepItem> items;
  final int? oilSprays;
  final String? alcoholType;
  final int alcoholQuantity;
  final NutrientInfo totalNutrients;
  final NutrientInfo perMealNutrients;
  final int totalMealCount;
  final int remainingCount;
  final DateTime createdAt;

  const MealPrep({
    this.id,
    required this.name,
    required this.items,
    this.oilSprays,
    this.alcoholType,
    this.alcoholQuantity = 0,
    required this.totalNutrients,
    required this.perMealNutrients,
    required this.totalMealCount,
    required this.remainingCount,
    required this.createdAt,
  });

  MealPrep copyWith({int? remainingCount}) => MealPrep(
        id: id,
        name: name,
        items: items,
        oilSprays: oilSprays,
        alcoholType: alcoholType,
        alcoholQuantity: alcoholQuantity,
        totalNutrients: totalNutrients,
        perMealNutrients: perMealNutrients,
        totalMealCount: totalMealCount,
        remainingCount: remainingCount ?? this.remainingCount,
        createdAt: createdAt,
      );

  Map<String, dynamic> toDbMap() => {
        'name': name,
        'items_json': jsonEncode(items.map((e) => e.toJson()).toList()),
        'oil_sprays': oilSprays,
        'alcohol_type': alcoholType,
        'alcohol_quantity': alcoholQuantity,
        'total_nutrients_json': jsonEncode(totalNutrients.toJson()),
        'per_meal_nutrients_json': jsonEncode(perMealNutrients.toJson()),
        'total_meal_count': totalMealCount,
        'remaining_count': remainingCount,
        'created_at': createdAt.toIso8601String(),
      };

  factory MealPrep.fromDbMap(Map<String, dynamic> map) {
    final itemsList = (jsonDecode(map['items_json'] as String) as List)
        .map((e) => MealPrepItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return MealPrep(
      id: map['id'] as int?,
      name: map['name'] as String,
      items: itemsList,
      oilSprays: map['oil_sprays'] as int?,
      alcoholType: map['alcohol_type'] as String?,
      alcoholQuantity: (map['alcohol_quantity'] as int?) ?? 0,
      totalNutrients: NutrientInfo.fromJson(
          jsonDecode(map['total_nutrients_json'] as String)
              as Map<String, dynamic>),
      perMealNutrients: NutrientInfo.fromJson(
          jsonDecode(map['per_meal_nutrients_json'] as String)
              as Map<String, dynamic>),
      totalMealCount: map['total_meal_count'] as int,
      remainingCount: map['remaining_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
