import 'package:cloud_firestore/cloud_firestore.dart';

/// A comment on a member's day, at
/// `squads/{squadId}/days/{YYYY-MM-DD}/comments/{commentId}`. Words beat emoji.
class SquadComment {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String text;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  const SquadComment({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.text,
    this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  String get displayText => isDeleted ? '[deleted]' : text;

  factory SquadComment.fromMap(String id, Map<String, dynamic> m) => SquadComment(
        id: id,
        fromUid: (m['fromUid'] as String?) ?? '',
        fromName: (m['fromName'] as String?) ?? 'Someone',
        toUid: (m['toUid'] as String?) ?? '',
        text: (m['text'] as String?) ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        editedAt: (m['editedAt'] as Timestamp?)?.toDate(),
        deletedAt: (m['deletedAt'] as Timestamp?)?.toDate(),
      );
}
