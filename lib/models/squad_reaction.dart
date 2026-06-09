import 'package:cloud_firestore/cloud_firestore.dart';

enum ReactionEmoji { fire, flex, clap }

extension ReactionEmojiGlyph on ReactionEmoji {
  String get glyph {
    switch (this) {
      case ReactionEmoji.fire:
        return '🔥';
      case ReactionEmoji.flex:
        return '💪';
      case ReactionEmoji.clap:
        return '👏';
    }
  }
}

/// squads/{squadId}/days/{date}/reactions/{autoId}. fromName is denormalized so
/// the reactor list renders without reading others' (own-only) users docs.
class SquadReaction {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final ReactionEmoji emoji;
  final DateTime? createdAt;

  const SquadReaction({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.emoji,
    this.createdAt,
  });

  factory SquadReaction.fromMap(String id, Map<String, dynamic> m) {
    final e = m['emoji'] as String?;
    return SquadReaction(
      id: id,
      fromUid: (m['fromUid'] as String?) ?? '',
      fromName: (m['fromName'] as String?)?.trim().isNotEmpty == true ? m['fromName'] as String : 'Someone',
      toUid: (m['toUid'] as String?) ?? '',
      emoji: ReactionEmoji.values.firstWhere((x) => x.name == e, orElse: () => ReactionEmoji.fire),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'emoji': emoji.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
