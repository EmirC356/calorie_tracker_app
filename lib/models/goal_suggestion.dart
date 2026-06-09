/// Lifecycle of a squadmate → me goal suggestion.
enum SuggestionStatus { pending, accepted, rejected, expired }

/// A goal a squadmate proposed to me. The proposed [Goal] definition is carried
/// as serialized JSON in [payloadJson] until I accept (and can tweak) it.
/// Suggestions expire 7 days after [suggestedAt]. Timestamps are UTC.
class GoalSuggestion {
  final int? id;
  final String fromUid;
  final String fromName;
  final String squadId;
  final DateTime suggestedAt; // UTC
  final DateTime expiresAt; // UTC
  final SuggestionStatus status;
  final String payloadJson; // serialized Goal definition pre-acceptance

  GoalSuggestion({
    this.id,
    required this.fromUid,
    required this.fromName,
    required this.squadId,
    required this.suggestedAt,
    required this.expiresAt,
    this.status = SuggestionStatus.pending,
    required this.payloadJson,
  });

  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);

  GoalSuggestion copyWith({
    int? id,
    String? fromUid,
    String? fromName,
    String? squadId,
    DateTime? suggestedAt,
    DateTime? expiresAt,
    SuggestionStatus? status,
    String? payloadJson,
  }) =>
      GoalSuggestion(
        id: id ?? this.id,
        fromUid: fromUid ?? this.fromUid,
        fromName: fromName ?? this.fromName,
        squadId: squadId ?? this.squadId,
        suggestedAt: suggestedAt ?? this.suggestedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        status: status ?? this.status,
        payloadJson: payloadJson ?? this.payloadJson,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'from_uid': fromUid,
        'from_name': fromName,
        'squad_id': squadId,
        'suggested_at': suggestedAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'status': status.name,
        'payload_json': payloadJson,
      };

  factory GoalSuggestion.fromMap(Map<String, dynamic> m) => GoalSuggestion(
        id: m['id'] as int?,
        fromUid: m['from_uid'] as String,
        fromName: m['from_name'] as String,
        squadId: m['squad_id'] as String,
        suggestedAt: DateTime.parse(m['suggested_at'] as String).toLocal(),
        expiresAt: DateTime.parse(m['expires_at'] as String).toLocal(),
        status: _statusFrom(m['status'] as String?),
        payloadJson: m['payload_json'] as String,
      );

  static SuggestionStatus _statusFrom(String? name) {
    for (final v in SuggestionStatus.values) {
      if (v.name == name) return v;
    }
    return SuggestionStatus.pending;
  }
}
