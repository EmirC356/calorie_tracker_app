import 'package:cloud_firestore/cloud_firestore.dart';
import 'squad_goal.dart';

/// How much of a member's day a *specific squad* can see. Stored on the member
/// doc (per-squad, per-user), not the global user doc.
enum SharingLevel { status, totals, full }

extension SharingLevelRank on SharingLevel {
  /// status < totals < full
  bool atLeast(SharingLevel other) => index >= other.index;
}

/// squads/{squadId}/members/{uid}
class SquadMember {
  final String uid;
  final DateTime? joinedAt;
  final SquadGoal goal;
  final SharingLevel sharingLevel;

  const SquadMember({
    required this.uid,
    this.joinedAt,
    this.goal = const SquadGoal(),
    this.sharingLevel = SharingLevel.status,
  });

  factory SquadMember.fromMap(String uid, Map<String, dynamic> map) => SquadMember(
        uid: uid,
        joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
        goal: SquadGoal.fromMap(map['goal'] as Map<String, dynamic>?),
        sharingLevel: SharingLevel.values.byName((map['sharingLevel'] as String?) ?? 'status'),
      );

  /// Field map for writes. joinedAt is written separately (server timestamp).
  Map<String, dynamic> toMap() => {
        'goal': goal.toMap(),
        'sharingLevel': sharingLevel.name,
      };

  SquadMember copyWith({SquadGoal? goal, SharingLevel? sharingLevel}) => SquadMember(
        uid: uid,
        joinedAt: joinedAt,
        goal: goal ?? this.goal,
        sharingLevel: sharingLevel ?? this.sharingLevel,
      );
}
