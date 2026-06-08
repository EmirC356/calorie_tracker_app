class WeightEntry {
  final int? id;
  final double weight; // kg
  final DateTime timestamp;
  final bool isEmptyStomach;

  const WeightEntry({
    this.id,
    required this.weight,
    required this.timestamp,
    required this.isEmptyStomach,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'weight': weight,
        'timestamp': timestamp.toIso8601String(),
        'isEmptyStomach': isEmptyStomach ? 1 : 0,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as int?,
        weight: (json['weight'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        isEmptyStomach: (json['isEmptyStomach'] as int) == 1,
      );
}
