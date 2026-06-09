import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

/// All Firestore reads/writes for the Squad feature. Phase 1 covers the
/// `users/{uid}` collection; squad/day/reaction operations are added in later
/// phases. [firestore] is injectable so tests can use FakeFirebaseFirestore.
class SquadService {
  final FirebaseFirestore _db;

  SquadService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Ensures `users/{uid}` exists, seeding displayName/photoURL from the Google
  /// account on first sign-in. Idempotent — never overwrites an existing doc.
  Future<AppUser> ensureUserDocument(User user) async {
    final ref = _users.doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      return AppUser.fromMap(snap.id, snap.data()!);
    }
    final appUser = AppUser(
      uid: user.uid,
      displayName: (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!
          : 'Athlete',
      photoURL: user.photoURL,
      fcmTokens: const [],
    );
    await ref.set({
      ...appUser.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return appUser;
  }

  Future<AppUser?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromMap(snap.id, snap.data()!);
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _users.doc(uid).update({'displayName': displayName});
  }

  /// Adds an FCM token to the user's token array (no duplicates). Used by the
  /// notification service in a later phase.
  Future<void> addFcmToken(String uid, String token) async {
    await _users.doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }
}
