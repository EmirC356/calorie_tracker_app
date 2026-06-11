import 'package:cloud_firestore/cloud_firestore.dart';

/// A member's weekly public commitment, at
/// `squads/{squadId}/intentions/{YYYY-Www}/members/{uid}`. Always squad-visible
/// (the public-commitment mechanic). Immutable once graded.
class SquadIntention {
  final String uid;
  final String text;
  final String? goalRef; // optional linked Calendar goal id
  final DateTime? declaredAt;
  final String gradedStatus; // 'unset' | 'hit' | 'partial' | 'missed'

  const SquadIntention({
    required this.uid,
    required this.text,
    this.goalRef,
    this.declaredAt,
    this.gradedStatus = 'unset',
  });

  bool get isGraded => gradedStatus != 'unset';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'text': text,
        if (goalRef != null) 'goalRef': goalRef,
        'declaredAt': declaredAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(declaredAt!),
        'gradedStatus': gradedStatus,
      };

  factory SquadIntention.fromMap(String uid, Map<String, dynamic> m) => SquadIntention(
        uid: uid,
        text: (m['text'] as String?) ?? '',
        goalRef: m['goalRef'] as String?,
        declaredAt: (m['declaredAt'] as Timestamp?)?.toDate(),
        gradedStatus: (m['gradedStatus'] as String?) ?? 'unset',
      );
}
