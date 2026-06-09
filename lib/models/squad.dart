import 'package:cloud_firestore/cloud_firestore.dart';

/// squads/{squadId}. Membership is a denormalized `memberUids` array (max 10)
/// for the "my squads" array-contains query.
class Squad {
  static const int maxMembers = 10;

  final String id;
  final String name;
  final String ownerUid;
  final List<String> memberUids;
  final String inviteCode;
  final DateTime? inviteCodeExpiresAt;
  final DateTime? createdAt;

  const Squad({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.inviteCode,
    this.inviteCodeExpiresAt,
    this.createdAt,
  });

  int get memberCount => memberUids.length;
  bool get isFull => memberUids.length >= maxMembers;
  bool isOwner(String uid) => uid == ownerUid;
  bool hasMember(String uid) => memberUids.contains(uid);
  bool get inviteExpired =>
      inviteCodeExpiresAt != null && DateTime.now().isAfter(inviteCodeExpiresAt!);

  factory Squad.fromMap(String id, Map<String, dynamic> map) => Squad(
        id: id,
        name: (map['name'] as String?) ?? 'Squad',
        ownerUid: (map['ownerUid'] as String?) ?? '',
        memberUids: (map['memberUids'] as List?)?.cast<String>() ?? const [],
        inviteCode: (map['inviteCode'] as String?) ?? '',
        inviteCodeExpiresAt: (map['inviteCodeExpiresAt'] as Timestamp?)?.toDate(),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      );
}
