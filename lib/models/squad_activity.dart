import 'package:cloud_firestore/cloud_firestore.dart';

/// One entry in the unified squad activity feed (`squads/{}/activity/{id}`),
/// written by Cloud Functions only. Carries denormalized actor/subject identity
/// so the feed renders without extra reads.
///
/// Canonical types: goalHit · streakMilestone · streakBroken · commentPosted ·
/// reactionSent · pauseStarted · pauseEnded · memberJoined · memberLeft ·
/// intentionSet · fullSquadDay · groupGoalHit · birthday. Legacy docs from the
/// first feed (streakLoss / pause / return, name in payload.displayName) are
/// mapped through [normalizedType] / [_actor] so they still render.
class SquadActivity {
  final String id;
  final String type;
  final String actorUid;
  final String actorName;
  final String? actorPhotoURL;
  final String? subjectUid;
  final String? subjectName;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  const SquadActivity({
    required this.id,
    required this.type,
    this.actorUid = '',
    this.actorName = '',
    this.actorPhotoURL,
    this.subjectUid,
    this.subjectName,
    this.payload = const {},
    this.createdAt,
  });

  factory SquadActivity.fromMap(String id, Map<String, dynamic> m) {
    final payload = ((m['payload'] as Map?) ?? const {}).cast<String, dynamic>();
    return SquadActivity(
      id: id,
      type: (m['type'] as String?) ?? 'event',
      actorUid: (m['actorUid'] as String?) ?? (payload['uid'] as String?) ?? '',
      actorName: (m['actorName'] as String?) ?? (payload['displayName'] as String?) ?? '',
      actorPhotoURL: m['actorPhotoURL'] as String?,
      subjectUid: m['subjectUid'] as String?,
      subjectName: m['subjectName'] as String?,
      payload: payload,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Maps the 3 legacy type strings onto the canonical set.
  String get normalizedType => switch (type) {
        'streakLoss' => 'streakBroken',
        'pause' => 'pauseStarted',
        'return' => 'pauseEnded',
        _ => type,
      };

  String get _actor => actorName.trim().isNotEmpty ? actorName : 'A squadmate';
  String get _subject =>
      (subjectName?.trim().isNotEmpty ?? false) ? subjectName! : 'a squadmate';

  static const _reactionGlyphs = {'fire': '🔥', 'flex': '💪', 'clap': '👏'};

  /// One-line human text for the feed row.
  String get line {
    final p = payload;
    switch (normalizedType) {
      case 'goalHit':
        return '$_actor hit their goal';
      case 'streakMilestone':
        return '$_actor hit a ${p['length'] ?? ''}-day streak 🔥'.replaceAll('  ', ' ');
      case 'streakBroken':
        return "$_actor's ${p['length'] ?? ''}-day streak ended".replaceAll('  ', ' ');
      case 'commentPosted':
        return "$_actor commented on $_subject's day";
      case 'reactionSent':
        final g = _reactionGlyphs[p['emoji']] ?? '👏';
        return '$_actor sent $g to $_subject';
      case 'pauseStarted':
        final until = (p['until'] as String?) ?? '';
        return '$_actor paused${until.isEmpty ? '' : ' until $until'}';
      case 'pauseEnded':
        return '$_actor is back';
      case 'memberJoined':
        return '$_actor joined the squad';
      case 'memberLeft':
        return '$_actor left the squad';
      case 'intentionSet':
        return '$_actor declared this week: "${p['text'] ?? ''}"';
      case 'fullSquadDay':
        return '🔥 Full squad day on ${p['date'] ?? ''}'.trim();
      case 'groupGoalHit':
        return "🎯 Group goal hit: ${p['title'] ?? 'a group goal'}";
      case 'birthday':
        return "🎂 Today is $_actor's birthday";
      default:
        return p['text'] as String? ?? 'Squad activity';
    }
  }

  String get emoji => switch (normalizedType) {
        'goalHit' => '✅',
        'streakMilestone' => '🔥',
        'streakBroken' => '💔',
        'commentPosted' => '💬',
        'reactionSent' => _reactionGlyphs[payload['emoji']] ?? '👋',
        'pauseStarted' => '🌴',
        'pauseEnded' => '💪',
        'memberJoined' => '👋',
        'memberLeft' => '✌️',
        'intentionSet' => '📣',
        'fullSquadDay' => '🔥',
        'groupGoalHit' => '🎯',
        'birthday' => '🎂',
        _ => '•',
      };
}
