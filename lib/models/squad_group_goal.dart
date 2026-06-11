import 'package:cloud_firestore/cloud_firestore.dart';

/// A shared squad goal everyone contributes toward, at
/// `squads/{squadId}/groupGoals/{goalId}`. Counterweight to the leaderboard.
class SquadGroupGoal {
  final String id;
  final String title;
  final String metric; // exerciseSessionsTotal | mealsLoggedTotal | ...
  final double target;
  final String aggregateMode; // sum | count-full-squad-days | unique-members-hit
  final String startDate; // YYYY-MM-DD
  final String endDate; // YYYY-MM-DD
  final String createdBy;
  final Map<String, double> contributions; // uid -> contributed amount
  final double currentValue; // denormalized sum for fast UI
  final DateTime? hitAt;

  const SquadGroupGoal({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    this.aggregateMode = 'sum',
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    this.contributions = const {},
    this.currentValue = 0,
    this.hitAt,
  });

  bool get isHit => currentValue >= target;
  double get progress => target <= 0 ? 0 : (currentValue / target).clamp(0, 1);

  bool isActiveOn(String dateKey) => dateKey.compareTo(startDate) >= 0 && dateKey.compareTo(endDate) <= 0;

  Map<String, dynamic> toCreateMap() => {
        'title': title,
        'metric': metric,
        'target': target,
        'aggregateMode': aggregateMode,
        'startDate': startDate,
        'endDate': endDate,
        'createdBy': createdBy,
        'contributions': <String, dynamic>{},
        'currentValue': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory SquadGroupGoal.fromMap(String id, Map<String, dynamic> m) => SquadGroupGoal(
        id: id,
        title: (m['title'] as String?) ?? '',
        metric: (m['metric'] as String?) ?? 'mealsLoggedTotal',
        target: (m['target'] as num?)?.toDouble() ?? 0,
        aggregateMode: (m['aggregateMode'] as String?) ?? 'sum',
        startDate: (m['startDate'] as String?) ?? '',
        endDate: (m['endDate'] as String?) ?? '',
        createdBy: (m['createdBy'] as String?) ?? '',
        contributions: ((m['contributions'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        currentValue: (m['currentValue'] as num?)?.toDouble() ?? 0,
        hitAt: (m['hitAt'] as Timestamp?)?.toDate(),
      );
}
