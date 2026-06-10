/// A single water-intake entry (millilitres at a timestamp).
class WaterEntry {
  final int? id;
  final int amountMl;
  final DateTime timestamp;

  WaterEntry({this.id, required this.amountMl, required this.timestamp});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'amount_ml': amountMl,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WaterEntry.fromMap(Map<String, dynamic> m) => WaterEntry(
        id: m['id'] as int?,
        amountMl: (m['amount_ml'] as num).toInt(),
        timestamp: DateTime.parse(m['timestamp'] as String),
      );
}
