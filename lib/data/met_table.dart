/// A physical activity with its MET (Metabolic Equivalent of Task) value.
/// Values approximate the Compendium of Physical Activities.
class MetActivity {
  final String name;
  final double met;
  const MetActivity(this.name, this.met);
}

class MetTable {
  static const List<MetActivity> activities = [
    MetActivity('Walking (casual)', 3.0),
    MetActivity('Walking (brisk)', 4.3),
    MetActivity('Running (8 km/h)', 8.3),
    MetActivity('Running (12 km/h)', 11.8),
    MetActivity('Cycling (leisure)', 4.0),
    MetActivity('Cycling (vigorous)', 8.0),
    MetActivity('Swimming (moderate)', 5.8),
    MetActivity('Weightlifting (light)', 3.5),
    MetActivity('Weightlifting (vigorous)', 6.0),
    MetActivity('HIIT', 8.0),
    MetActivity('Rowing (moderate)', 7.0),
    MetActivity('Elliptical trainer', 5.0),
    MetActivity('Jump rope', 11.0),
    MetActivity('Hiking', 6.0),
    MetActivity('Yoga', 2.5),
    MetActivity('Pilates', 3.0),
    MetActivity('Soccer', 7.0),
    MetActivity('Basketball', 6.5),
    MetActivity('Tennis', 7.3),
  ];

  /// kcal = MET × body weight (kg) × duration (hours).
  static double caloriesBurned({
    required double met,
    required double weightKg,
    required int minutes,
  }) =>
      met * weightKg * (minutes / 60.0);
}
