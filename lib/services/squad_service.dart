import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/squad.dart';
import '../models/squad_member.dart';
import 'invite_code.dart';

/// A user-facing failure during a squad operation (shown in a SnackBar).
class SquadException implements Exception {
  final String message;
  const SquadException(this.message);
  @override
  String toString() => message;
}

/// All Firestore reads/writes for the Squad feature. [firestore] is injectable
/// so tests can use FakeFirebaseFirestore (no live Firebase).
class SquadService {
  final FirebaseFirestore _db;

  SquadService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _squads => _db.collection('squads');
  // code -> {squadId, expiresAt}. Lets a non-member resolve a squad by code
  // without read access to the (member-only) squad doc.
  CollectionReference<Map<String, dynamic>> get _squadCodes => _db.collection('squadCodes');

  // ── users/{uid} ─────────────────────────────────────────────────────────────

  Future<AppUser> ensureUserDocument(User user) async {
    final ref = _users.doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return AppUser.fromMap(snap.id, snap.data()!);
    final appUser = AppUser(
      uid: user.uid,
      displayName: (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName! : 'Athlete',
      photoURL: user.photoURL,
    );
    await ref.set({...appUser.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    return appUser;
  }

  Future<AppUser?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    return snap.exists ? AppUser.fromMap(snap.id, snap.data()!) : null;
  }

  Future<void> updateDisplayName(String uid, String displayName) =>
      _users.doc(uid).update({'displayName': displayName});

  Future<void> addFcmToken(String uid, String token) => _users.doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });

  // ── squads ──────────────────────────────────────────────────────────────────

  /// Creates a squad with [ownerUid] as owner + sole member, a fresh invite
  /// code, and the owner's default member doc.
  Future<Squad> createSquad({
    required String name,
    required String ownerUid,
    Random? random,
  }) async {
    final cleanName = name.trim().isEmpty ? 'My Squad' : name.trim();
    final code = InviteCode.generate(random);
    final expiresAt = InviteCode.expiryFrom();
    final ref = _squads.doc();

    // The squad doc must exist before the code doc, because the squadCodes
    // create rule verifies ownership via get(squad) and rules don't see other
    // writes in the same batch. So: create the squad first, then member+code.
    await ref.set({
      'name': cleanName,
      'ownerUid': ownerUid,
      'memberUids': [ownerUid],
      'inviteCode': code,
      'inviteCodeExpiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final batch = _db.batch();
    batch.set(ref.collection('members').doc(ownerUid), {
      'joinedAt': FieldValue.serverTimestamp(),
      ...const SquadMember(uid: '').toMap(),
    });
    batch.set(_squadCodes.doc(code), {
      'squadId': ref.id,
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    await batch.commit();

    final snap = await ref.get();
    return Squad.fromMap(snap.id, snap.data()!);
  }

  /// Resolves [code] via `squadCodes`, then adds [uid] to the squad. Avoids
  /// reading the (member-only) squad doc by using arrayUnion; security rules
  /// enforce the ≤10 cap, code expiry, and self-only addition.
  Future<Squad> joinSquadByCode({required String code, required String uid}) async {
    final trimmed = code.trim();
    if (!InviteCode.isValidFormat(trimmed)) {
      throw const SquadException('Enter a valid 6-digit code.');
    }
    final codeSnap = await _squadCodes.doc(trimmed).get();
    if (!codeSnap.exists) throw const SquadException('No squad found for that code.');
    final squadId = codeSnap.data()!['squadId'] as String?;
    final expiresAt = (codeSnap.data()!['expiresAt'] as Timestamp?)?.toDate();
    if (squadId == null) throw const SquadException('That code is no longer valid.');
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw const SquadException('That invite code has expired.');
    }

    final squadRef = _squads.doc(squadId);
    try {
      final batch = _db.batch();
      batch.update(squadRef, {'memberUids': FieldValue.arrayUnion([uid])});
      batch.set(squadRef.collection('members').doc(uid), {
        'joinedAt': FieldValue.serverTimestamp(),
        ...const SquadMember(uid: '').toMap(),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const SquadException(
            'Could not join — the squad may be full (10 max), the code expired, or you are already a member.');
      }
      rethrow;
    }

    final snap = await squadRef.get(); // now a member → read allowed
    return Squad.fromMap(snap.id, snap.data()!);
  }

  /// Owner-only. Rotates the code; the old one stops working immediately.
  Future<String> regenerateInviteCode(String squadId, {Random? random}) async {
    final squadSnap = await _squads.doc(squadId).get();
    final oldCode = squadSnap.data()?['inviteCode'] as String?;
    final code = InviteCode.generate(random);
    final expiresAt = InviteCode.expiryFrom();

    final batch = _db.batch();
    batch.update(_squads.doc(squadId), {
      'inviteCode': code,
      'inviteCodeExpiresAt': Timestamp.fromDate(expiresAt),
    });
    batch.set(_squadCodes.doc(code), {
      'squadId': squadId,
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    if (oldCode != null && oldCode.isNotEmpty && oldCode != code) {
      batch.delete(_squadCodes.doc(oldCode));
    }
    await batch.commit();
    return code;
  }

  /// Streams the user's squads. Sorted newest-first client-side so the query
  /// stays single-field (no composite index needed) and the read rule can match
  /// the array-contains filter.
  Stream<List<Squad>> watchMySquads(String uid) => _squads
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((qs) {
        final list = qs.docs.map((d) => Squad.fromMap(d.id, d.data())).toList();
        list.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  Stream<Squad?> watchSquad(String squadId) => _squads
      .doc(squadId)
      .snapshots()
      .map((d) => d.exists ? Squad.fromMap(d.id, d.data()!) : null);

  Future<Squad?> getSquad(String squadId) async {
    final snap = await _squads.doc(squadId).get();
    return snap.exists ? Squad.fromMap(snap.id, snap.data()!) : null;
  }
}
