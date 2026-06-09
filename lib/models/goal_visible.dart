/// Cloud DTO for a squad-visible goal occurrence, stored at
/// `users/{uid}/goalsVisible/{goalId}_{YYYY-MM-DD}`. Only aggregate, non-private
/// fields leave the device — never the goal's notes.
///
/// Read access is gated by [readerUids] (denormalized — see the rules): the
/// union of memberUids across every squad the owner currently belongs to, so a
/// squadmate query `where readerUids array-contains me` matches the
/// `uid() in resource.data.readerUids` rule in O(1). [squadIds] records which
/// squads it was shared to (for reference / future per-squad gating).
class GoalVisible {
  final String id; // "{goalId}_{YYYY-MM-DD}"
  final String ownerUid;
  final String goalTitle;
  final String category;
  final int colorArgb;
  final String priority;
  final String date; // YYYY-MM-DD
  final String status; // OccurrenceStatus name
  final String? period; // GoalPeriod name (tracked goals)
  final String? metricSummary; // e.g. "1820/2200 kcal"
  final List<String> squadIds;
  final List<String> readerUids;

  const GoalVisible({
    required this.id,
    required this.ownerUid,
    required this.goalTitle,
    required this.category,
    required this.colorArgb,
    required this.priority,
    required this.date,
    required this.status,
    this.period,
    this.metricSummary,
    this.squadIds = const [],
    this.readerUids = const [],
  });

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'goalTitle': goalTitle,
        'category': category,
        'colorArgb': colorArgb,
        'priority': priority,
        'date': date,
        'status': status,
        'period': period,
        'metricSummary': metricSummary,
        'squadIds': squadIds,
        'readerUids': readerUids,
      };

  factory GoalVisible.fromMap(String id, Map<String, dynamic> m) => GoalVisible(
        id: id,
        ownerUid: (m['ownerUid'] ?? '') as String,
        goalTitle: (m['goalTitle'] ?? '') as String,
        category: (m['category'] ?? '') as String,
        colorArgb: (m['colorArgb'] as num?)?.toInt() ?? 0,
        priority: (m['priority'] ?? 'medium') as String,
        date: (m['date'] ?? '') as String,
        status: (m['status'] ?? 'open') as String,
        period: m['period'] as String?,
        metricSummary: m['metricSummary'] as String?,
        squadIds: (m['squadIds'] as List?)?.cast<String>() ?? const [],
        readerUids: (m['readerUids'] as List?)?.cast<String>() ?? const [],
      );
}
