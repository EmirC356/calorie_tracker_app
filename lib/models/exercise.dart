class Exercise {
  final int? id;
  final String name;
  final int durationMinutes;
  final double caloriesBurned;
  final DateTime timestamp;
  final String? notes;
  final String intensity; // low, medium, high

  /// When set (YYYY-MM-DD), a make-up recovering that missed squad day.
  final String? makeupForDate;

  Exercise({
    this.id,
    required this.name,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.timestamp,
    this.notes,
    this.intensity = 'medium',
    this.makeupForDate,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int?,
      name: json['name'] as String,
      durationMinutes: json['durationMinutes'] as int,
      caloriesBurned: (json['caloriesBurned'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String?,
      intensity: json['intensity'] as String? ?? 'medium',
      makeupForDate: (json['makeupForDate'] ?? json['makeup_for_date']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'intensity': intensity,
      'makeupForDate': makeupForDate,
    };
  }
}
