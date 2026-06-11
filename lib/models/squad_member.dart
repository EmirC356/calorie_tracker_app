import 'package:cloud_firestore/cloud_firestore.dart';
import 'squad_goal.dart';
import 'squad_pause.dart';
import 'profile_goal_snapshot.dart';

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
  final bool muted;
  final SquadPause pause;

  /// Presence: bumped by the snapshot/heartbeat on activity. [ghostedSince] is
  /// set by the ghost-sweep Cloud Function after 72h of silence.
  final DateTime? lastActivityAt;
  final DateTime? ghostedSince;

  /// When true (default), the squad-effective goal is derived from
  /// [profileGoalSnapshot] (the user's profile Health Goals). When false, the
  /// explicit [goal] is an override for this squad.
  final bool inheritedFromProfile;
  final ProfileGoalSnapshot profileGoalSnapshot;

  const SquadMember({
    required this.uid,
    this.joinedAt,
    this.goal = const SquadGoal(),
    this.sharingLevel = SharingLevel.status,
    this.displayName = 'Athlete',
    this.photoURL,
    this.muted = false,
    this.pause = const SquadPause(),
    this.lastActivityAt,
    this.ghostedSince,
    this.inheritedFromProfile = true,
    this.profileGoalSnapshot = const ProfileGoalSnapshot(),
  });

  /// The goal the daily evaluator + UI should use: the profile snapshot when
  /// inherited and non-empty, otherwise the explicit [goal] (back-compat: an
  /// existing member with a manual goal and no snapshot keeps using [goal]).
  SquadGoal get effectiveGoal =>
      inheritedFromProfile && !profileGoalSnapshot.isEmpty ? profileGoalSnapshot.toDailyGoal() : goal;

  factory SquadMember.fromMap(String uid, Map<String, dynamic> map) => SquadMember(
        uid: uid,
        joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
        goal: SquadGoal.fromMap(map['goal'] as Map<String, dynamic>?),
        sharingLevel: SharingLevel.values.byName((map['sharingLevel'] as String?) ?? 'status'),
        displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
            ? map['displayName'] as String
            : 'Athlete',
        photoURL: map['photoURL'] as String?,
        muted: (map['muted'] as bool?) ?? false,
        pause: SquadPause.fromMap(map['pause'] as Map<String, dynamic>?),
        lastActivityAt: (map['lastActivityAt'] as Timestamp?)?.toDate(),
        ghostedSince: (map['ghostedSince'] as Timestamp?)?.toDate(),
        inheritedFromProfile: (map['inheritedFromProfile'] as bool?) ?? true,
        profileGoalSnapshot: ProfileGoalSnapshot.fromMap(map['profileGoalSnapshot'] as Map<String, dynamic>?),
      );

  /// Field map for writes. joinedAt is written separately (server timestamp).
  Map<String, dynamic> toMap() => {
        'goal': goal.toMap(),
        'sharingLevel': sharingLevel.name,
        'displayName': displayName,
        'photoURL': photoURL,
      };

  SquadMember copyWith({
    SquadGoal? goal,
    SharingLevel? sharingLevel,
    SquadPause? pause,
    bool? inheritedFromProfile,
    ProfileGoalSnapshot? profileGoalSnapshot,
  }) =>
      SquadMember(
        uid: uid,
        joinedAt: joinedAt,
        goal: goal ?? this.goal,
        sharingLevel: sharingLevel ?? this.sharingLevel,
        displayName: displayName,
        photoURL: photoURL,
        muted: muted,
        pause: pause ?? this.pause,
        inheritedFromProfile: inheritedFromProfile ?? this.inheritedFromProfile,
        profileGoalSnapshot: profileGoalSnapshot ?? this.profileGoalSnapshot,
      );
}
