import 'package:cloud_firestore/cloud_firestore.dart';
import 'squad_goal.dart';

/// How much of a member's day a *specific squad* can see. Stored on the member
/// doc (per-squad, per-user), not the global user doc.
enum SharingLevel { status, totals, full }

extension SharingLevelRank on SharingLevel {
  /// status < totals < full
  bool atLeast(SharingLevel other) => index >= other.index;
}

/// squads/{squadId}/members/{uid}. displayName/photoURL are denormalized from
/// the user's profile so squadmates can show names/avatars without reading each
/// other's (own-only) users doc.
class SquadMember {
  final String uid;
  final DateTime? joinedAt;
  final SquadGoal goal;
  final SharingLevel sharingLevel;
  final String displayName;
  final String? photoURL;

  const SquadMember({
    required this.uid,
    this.joinedAt,
    this.goal = const SquadGoal(),
    this.sharingLevel = SharingLevel.status,
    this.displayName = 'Athlete',
    this.photoURL,
  });

  factory SquadMember.fromMap(String uid, Map<String, dynamic> map) => SquadMember(
        uid: uid,
        joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
        goal: SquadGoal.fromMap(map['goal'] as Map<String, dynamic>?),
        sharingLevel: SharingLevel.values.byName((map['sharingLevel'] as String?) ?? 'status'),
        displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
            ? map['displayName'] as String
            : 'Athlete',
        photoURL: map['photoURL'] as String?,
      );

  /// Field map for writes. joinedAt is written separately (server timestamp).
  Map<String, dynamic> toMap() => {
        'goal': goal.toMap(),
        'sharingLevel': sharingLevel.name,
        'displayName': displayName,
        'photoURL': photoURL,
      };

  SquadMember copyWith({SquadGoal? goal, SharingLevel? sharingLevel}) => SquadMember(
        uid: uid,
        joinedAt: joinedAt,
        goal: goal ?? this.goal,
        sharingLevel: sharingLevel ?? this.sharingLevel,
        displayName: displayName,
        photoURL: photoURL,
      );
}
