/// A single day's logged-activity rollup, used by the Calendar's day-summary
/// chips and the Day view's Activity section. Purely derived from the existing
/// meal/exercise/weight data — no new storage.
class DayActivity {
  final int mealCount;
  final double calories;
  final int exerciseCount;
  final int exerciseMinutes;
  final bool hasWeight;
  final double? weightKg;

  const DayActivity({
    this.mealCount = 0,
    this.calories = 0,
    this.exerciseCount = 0,
    this.exerciseMinutes = 0,
    this.hasWeight = false,
    this.weightKg,
  });

  bool get isEmpty =>
      mealCount == 0 && exerciseCount == 0 && !hasWeight;
}
