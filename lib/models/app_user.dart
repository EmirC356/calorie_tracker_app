import 'package:cloud_firestore/cloud_firestore.dart';

/// A signed-in user's cloud profile (Firestore `users/{uid}`). This is the only
/// identity data that leaves the device; meals/exercises/weight stay local.
class AppUser {
  final String uid;
  final String displayName;
  final String? photoURL;
  final List<String> fcmTokens;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.displayName,
    this.photoURL,
    this.fcmTokens = const [],
    this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
            ? map['displayName'] as String
            : 'Athlete',
        photoURL: map['photoURL'] as String?,
        fcmTokens: (map['fcmTokens'] as List?)?.cast<String>() ?? const [],
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      );

  /// Field map for writes. `createdAt` is written separately by the service
  /// with a server timestamp on first create.
  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoURL': photoURL,
        'fcmTokens': fcmTokens,
      };

  AppUser copyWith({String? displayName, String? photoURL, List<String>? fcmTokens}) =>
      AppUser(
        uid: uid,
        displayName: displayName ?? this.displayName,
        photoURL: photoURL ?? this.photoURL,
        fcmTokens: fcmTokens ?? this.fcmTokens,
        createdAt: createdAt,
      );
}
