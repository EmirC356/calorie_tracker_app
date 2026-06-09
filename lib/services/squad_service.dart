import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/squad.dart';
import '../models/squad_member.dart';
import '../models/squad_goal.dart';
import '../models/squad_day_entry.dart';
import '../models/squad_reaction.dart';
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
    String displayName = 'Athlete',
    String? photoURL,
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
      ...SquadMember(uid: '', displayName: displayName, photoURL: photoURL).toMap(),
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
  Future<Squad> joinSquadByCode({
    required String code,
    required String uid,
    String displayName = 'Athlete',
    String? photoURL,
  }) async {
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
        ...SquadMember(uid: '', displayName: displayName, photoURL: photoURL).toMap(),
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

  // ── members: goal + sharing (self) ──────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _memberRef(String squadId, String uid) =>
      _squads.doc(squadId).collection('members').doc(uid);

  Stream<SquadMember?> watchMember(String squadId, String uid) => _memberRef(squadId, uid)
      .snapshots()
      .map((d) => d.exists ? SquadMember.fromMap(d.id, d.data()!) : null);

  Stream<List<SquadMember>> watchMembers(String squadId) =>
      _squads.doc(squadId).collection('members').snapshots().map(
          (qs) => qs.docs.map((d) => SquadMember.fromMap(d.id, d.data())).toList());

  Future<SquadMember?> getMember(String squadId, String uid) async {
    final snap = await _memberRef(squadId, uid).get();
    return snap.exists ? SquadMember.fromMap(snap.id, snap.data()!) : null;
  }

  Future<List<Squad>> getMySquadsOnce(String uid) async {
    final qs = await _squads.where('memberUids', arrayContains: uid).get();
    return qs.docs.map((d) => Squad.fromMap(d.id, d.data())).toList();
  }

  Future<void> updateGoal(String squadId, String uid, SquadGoal goal) =>
      _memberRef(squadId, uid).set({'goal': goal.toMap()}, SetOptions(merge: true));

  Future<void> updateSharingLevel(String squadId, String uid, SharingLevel level) =>
      _memberRef(squadId, uid).set({'sharingLevel': level.name}, SetOptions(merge: true));

  // ── owner controls ──────────────────────────────────────────────────────────

  Future<void> renameSquad(String squadId, String name) =>
      _squads.doc(squadId).update({'name': name.trim()});

  Future<void> transferOwnership(String squadId, String newOwnerUid) =>
      _squads.doc(squadId).update({'ownerUid': newOwnerUid});

  /// Owner removes another member: drop them from memberUids and delete their
  /// member doc.
  Future<void> kickMember(String squadId, String memberUid) async {
    final batch = _db.batch();
    batch.update(_squads.doc(squadId), {'memberUids': FieldValue.arrayRemove([memberUid])});
    batch.delete(_memberRef(squadId, memberUid));
    await batch.commit();
  }

  /// Self-leave: remove yourself from memberUids and delete your member doc.
  /// Owners can't leave — they transfer ownership or delete the squad.
  Future<void> leaveSquad(String squadId, String uid) async {
    final batch = _db.batch();
    batch.update(_squads.doc(squadId), {'memberUids': FieldValue.arrayRemove([uid])});
    batch.delete(_memberRef(squadId, uid));
    await batch.commit();
  }

  /// Owner deletes the whole squad: member docs + invite-code lookup + the
  /// squad doc. Day/reaction subcollections (if any) are left to the 30-day
  /// prune; they become unreadable once the squad doc is gone.
  // ── day entries (snapshots) ─────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _entriesCol(String squadId, String dateKey) =>
      _squads.doc(squadId).collection('days').doc(dateKey).collection('entries');

  Future<void> writeDayEntry({
    required String squadId,
    required String dateKey,
    required String uid,
    required Map<String, dynamic> data,
  }) =>
      _entriesCol(squadId, dateKey).doc(uid).set(data, SetOptions(merge: true));

  Stream<List<SquadDayEntry>> watchDayEntries(String squadId, String dateKey) =>
      _entriesCol(squadId, dateKey).snapshots().map(
          (qs) => qs.docs.map((d) => SquadDayEntry.fromMap(d.id, d.data())).toList());

  // ── reactions ───────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _reactionsCol(String squadId, String dateKey) =>
      _squads.doc(squadId).collection('days').doc(dateKey).collection('reactions');

  Future<void> addReaction({
    required String squadId,
    required String dateKey,
    required String fromUid,
    required String fromName,
    required String toUid,
    required ReactionEmoji emoji,
  }) =>
      _reactionsCol(squadId, dateKey).add({
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'emoji': emoji.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> removeReaction({required String squadId, required String dateKey, required String reactionId}) =>
      _reactionsCol(squadId, dateKey).doc(reactionId).delete();

  Stream<List<SquadReaction>> watchReactions(String squadId, String dateKey) =>
      _reactionsCol(squadId, dateKey).snapshots().map(
          (qs) => qs.docs.map((d) => SquadReaction.fromMap(d.id, d.data())).toList());

  Future<void> deleteSquad(String squadId) async {
    final ref = _squads.doc(squadId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final code = snap.data()?['inviteCode'] as String?;
    final members = await ref.collection('members').get();

    final batch = _db.batch();
    for (final m in members.docs) {
      batch.delete(m.reference);
    }
    if (code != null && code.isNotEmpty) batch.delete(_squadCodes.doc(code));
    batch.delete(ref);
    await batch.commit();
  }
}
