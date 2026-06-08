import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/database_service.dart';

class MealPrepProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<MealPrep> _preps = [];

  List<MealPrep> get preps => List.unmodifiable(_preps);

  Future<void> loadPreps() async {
    _preps = await _db.getMealPreps();
    notifyListeners();
  }

  Future<void> addPrep(MealPrep prep) async {
    final id = await _db.insertMealPrep(prep);
    _preps.insert(0, MealPrep(
      id: id,
      name: prep.name,
      items: prep.items,
      oilSprays: prep.oilSprays,
      alcoholType: prep.alcoholType,
      alcoholQuantity: prep.alcoholQuantity,
      totalNutrients: prep.totalNutrients,
      perMealNutrients: prep.perMealNutrients,
      totalMealCount: prep.totalMealCount,
      remainingCount: prep.remainingCount,
      createdAt: prep.createdAt,
    ));
    notifyListeners();
  }

  Future<void> consumeOne(MealPrep prep) async {
    if (prep.remainingCount <= 0 || prep.id == null) return;
    final newCount = prep.remainingCount - 1;
    await _db.updateMealPrepRemaining(prep.id!, newCount);
    final idx = _preps.indexWhere((p) => p.id == prep.id);
    if (idx != -1) {
      _preps[idx] = prep.copyWith(remainingCount: newCount);
    }
    notifyListeners();
  }

  Future<void> deletePrep(int id) async {
    await _db.deleteMealPrep(id);
    _preps.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
