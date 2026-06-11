import 'package:cloud_firestore/cloud_firestore.dart';

/// One entry in the unified squad activity feed (`squads/{}/activity/{id}`),
/// written by Cloud Functions. type: streakLoss | fullSquadDay | groupGoalHit.
class SquadActivity {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  const SquadActivity({required this.id, required this.type, this.payload = const {}, this.createdAt});

  factory SquadActivity.fromMap(String id, Map<String, dynamic> m) => SquadActivity(
        id: id,
        type: (m['type'] as String?) ?? 'event',
        payload: ((m['payload'] as Map?) ?? const {}).cast<String, dynamic>(),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  /// A human line for the feed.
  String get line {
    final p = payload;
    switch (type) {
      case 'streakLoss':
        return "${p['displayName'] ?? 'A squadmate'}'s ${p['length'] ?? ''}-day streak ended on ${p['date'] ?? ''}".replaceAll('  ', ' ');
      case 'fullSquadDay':
        return '🔥 Full squad day — everyone hit on ${p['date'] ?? ''}';
      case 'groupGoalHit':
        return "🎯 Squad hit '${p['title'] ?? 'a group goal'}'";
      case 'pause':
        final until = (p['until'] as String?) ?? '';
        return "${p['displayName'] ?? 'A squadmate'} paused${until.isEmpty ? '' : ' til $until'}";
      case 'return':
        return '${p['displayName'] ?? 'A squadmate'} is back';
      default:
        return p['text'] as String? ?? 'Squad activity';
    }
  }

  String get emoji => switch (type) {
        'streakLoss' => '💔',
        'fullSquadDay' => '🔥',
        'groupGoalHit' => '🎯',
        'pause' => '🌴',
        'return' => '💪',
        _ => '•',
      };
}
