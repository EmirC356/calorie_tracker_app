import 'goal_occurrence.dart';

/// Pure value object returned by the GoalEvaluator (Phase 3) when evaluating a
/// tracked goal occurrence. Carries the resulting [status] plus the numbers the
/// UI needs to draw a progress ring and label.
class GoalEvaluationResult {
  final OccurrenceStatus status;
  final double? metricValue;
  final double? targetValue;
  final double? progressPercent; // 0..100
  final String? message;

  const GoalEvaluationResult({
    required this.status,
    this.metricValue,
    this.targetValue,
    this.progressPercent,
    this.message,
  });

  @override
  String toString() =>
      'GoalEvaluationResult(status: $status, metric: $metricValue, '
      'target: $targetValue, progress: $progressPercent, message: $message)';
}
