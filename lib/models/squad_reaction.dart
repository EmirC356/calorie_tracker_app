import 'package:cloud_firestore/cloud_firestore.dart';

enum ReactionEmoji { fire, flex, clap }

/// Minimum gap between nudges to the *same* member from the same sender.
const Duration kReactionCooldown = Duration(minutes: 5);

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

/// The latest emoji each member *received* (by createdAt), keyed by recipient
/// uid. Used to show an emoji next to a member's name. Pure — unit-tested.
Map<String, ReactionEmoji> latestEmojiByRecipient(List<SquadReaction> reactions) {
  final latest = <String, SquadReaction>{};
  for (final r in reactions) {
    final cur = latest[r.toUid];
    final rt = r.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final ct = cur?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (cur == null || rt.isAfter(ct)) latest[r.toUid] = r;
  }
  return latest.map((k, v) => MapEntry(k, v.emoji));
}

/// Remaining cooldown before [fromUid] may nudge [toUid] again, given prior
/// [reactions]. Zero when allowed. Pure — unit-tested.
Duration reactionCooldownRemaining(
  List<SquadReaction> reactions,
  String fromUid,
  String toUid,
  DateTime now, [
  Duration cooldown = kReactionCooldown,
]) {
  DateTime? last;
  for (final r in reactions) {
    if (r.fromUid == fromUid && r.toUid == toUid && r.createdAt != null) {
      if (last == null || r.createdAt!.isAfter(last)) last = r.createdAt;
    }
  }
  if (last == null) return Duration.zero;
  final remaining = cooldown - now.difference(last);
  return remaining.isNegative ? Duration.zero : remaining;
}
