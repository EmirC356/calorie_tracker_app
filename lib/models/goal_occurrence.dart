import 'date_helpers.dart';

/// Status of a single goal occurrence.
///
/// Named `OccurrenceStatus` (not `GoalStatus`) to avoid colliding with the
/// Squad feature's existing `GoalStatus { hit, inProgress, missed }`.
enum OccurrenceStatus { open, done, failed, skipped }

/// One materialized scheduled instance of a [Goal] on a specific date.
///
/// Occurrences are materialized lazily: the recurrence engine is the source of
/// truth for *which* dates a goal lands on, and a row is written here only when
/// the user interacts with it (marks done/edits/notes) or the end-of-period
/// sweep records a final status. [occurrenceDate] is a local date-only value;
/// [doneAt] is a UTC timestamp.
class GoalOccurrence {
  final int? id;
  final int goalId;
  final DateTime occurrenceDate; // local date-only (midnight)
  final OccurrenceStatus status;
  final DateTime? doneAt; // UTC timestamp
  final bool overrideFlag; // true if status was flipped after period end
  final double? periodValueCached; // tracked: metric value when evaluated
  final String? notes;

  GoalOccurrence({
    this.id,
    required this.goalId,
    required DateTime occurrenceDate,
    this.status = OccurrenceStatus.open,
    this.doneAt,
    this.overrideFlag = false,
    this.periodValueCached,
    this.notes,
  }) : occurrenceDate = dateOnly(occurrenceDate);

  GoalOccurrence copyWith({
    int? id,
    int? goalId,
    DateTime? occurrenceDate,
    OccurrenceStatus? status,
    DateTime? doneAt,
    bool? overrideFlag,
    double? periodValueCached,
    String? notes,
    bool clearDoneAt = false,
    bool clearPeriodValue = false,
    bool clearNotes = false,
  }) =>
      GoalOccurrence(
        id: id ?? this.id,
        goalId: goalId ?? this.goalId,
        occurrenceDate: occurrenceDate ?? this.occurrenceDate,
        status: status ?? this.status,
        doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
        overrideFlag: overrideFlag ?? this.overrideFlag,
        periodValueCached:
            clearPeriodValue ? null : (periodValueCached ?? this.periodValueCached),
        notes: clearNotes ? null : (notes ?? this.notes),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'goal_id': goalId,
        'occurrence_date': ymd(occurrenceDate),
        'status': status.name,
        'done_at': doneAt?.toUtc().toIso8601String(),
        'override_flag': overrideFlag ? 1 : 0,
        'period_value_cached': periodValueCached,
        'notes': notes,
      };

  factory GoalOccurrence.fromMap(Map<String, dynamic> m) => GoalOccurrence(
        id: m['id'] as int?,
        goalId: (m['goal_id'] as num).toInt(),
        occurrenceDate: parseYmd(m['occurrence_date'] as String),
        status: _statusFrom(m['status'] as String?),
        doneAt: m['done_at'] == null
            ? null
            : DateTime.parse(m['done_at'] as String).toLocal(),
        overrideFlag: (m['override_flag'] as num?)?.toInt() == 1,
        periodValueCached: (m['period_value_cached'] as num?)?.toDouble(),
        notes: m['notes'] as String?,
      );

  static OccurrenceStatus _statusFrom(String? name) {
    for (final v in OccurrenceStatus.values) {
      if (v.name == name) return v;
    }
    return OccurrenceStatus.open;
  }
}
