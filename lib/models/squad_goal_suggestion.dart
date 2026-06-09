import 'package:cloud_firestore/cloud_firestore.dart';

/// Cloud DTO for a squadmate → me goal suggestion, stored at
/// `squads/{squadId}/suggestions/{id}`. The proposed goal travels as serialized
/// JSON in [payloadJson] until the recipient accepts (and can tweak) it.
class SquadGoalSuggestion {
  final String id; // firestore doc id
  final String squadId;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String payloadJson;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String status; // pending | accepted | rejected | expired

  const SquadGoalSuggestion({
    required this.id,
    required this.squadId,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.payloadJson,
    this.createdAt,
    this.expiresAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'payloadJson': payloadJson,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
        'status': status,
      };

  /// Builds from a Firestore doc. [squadId] is the parent squad id
  /// (`doc.reference.parent.parent!.id` for a collection-group query).
  factory SquadGoalSuggestion.fromDoc(
          String id, String squadId, Map<String, dynamic> m) =>
      SquadGoalSuggestion(
        id: id,
        squadId: squadId,
        fromUid: (m['fromUid'] ?? '') as String,
        fromName: (m['fromName'] ?? '') as String,
        toUid: (m['toUid'] ?? '') as String,
        payloadJson: (m['payloadJson'] ?? '{}') as String,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        expiresAt: (m['expiresAt'] as Timestamp?)?.toDate(),
        status: (m['status'] ?? 'pending') as String,
      );
}
