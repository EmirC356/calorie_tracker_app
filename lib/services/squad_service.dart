import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/squad.dart';
import '../models/squad_member.dart';
import '../models/squad_pause.dart';
import '../models/squad_intention.dart';
import '../models/squad_group_goal.dart';
import '../models/squad_comment.dart';
import '../models/squad_activity.dart';
import '../models/squad_goal.dart';
import '../models/squad_day_entry.dart';
import '../models/squad_reaction.dart';
import '../models/goal_visible.dart';
import '../models/squad_goal_suggestion.dart';
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

  /// Updates the user's profile name AND fans it out to the denormalized
  /// `members/{uid}.displayName` doc in every squad they belong to, so existing
  /// squads show the new name (they were denormalized at join time).
  Future<void> updateDisplayName(String uid, String displayName) async {
    final squads = await _squads.where('memberUids', arrayContains: uid).get();
    final batch = _db.batch();
    batch.set(_users.doc(uid), {'displayName': displayName}, SetOptions(merge: true));
    for (final s in squads.docs) {
      batch.set(_memberRef(s.id, uid), {'displayName': displayName}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> addFcmToken(String uid, String token) => _users.doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });

  Future<void> removeFcmToken(String uid, String token) => _users.doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });

  /// Used by the scheduled end-of-day summary to fire at the user's local 22:00.
  Future<void> setTimezoneOffset(String uid, int minutes) =>
      _users.doc(uid).set({'tzOffsetMinutes': minutes}, SetOptions(merge: true));

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

  /// Per-squad notification mute (checked by the Cloud Functions before push).
  Future<void> updateMuted(String squadId, String uid, bool muted) =>
      _memberRef(squadId, uid).set({'muted': muted}, SetOptions(merge: true));

  /// Writes the member's pause/vacation object (merge — keeps goal/sharing).
  Future<void> setPause(String squadId, String uid, SquadPause pause) =>
      _memberRef(squadId, uid).set({'pause': pause.toMap()}, SetOptions(merge: true));

  /// Stamps `lastActivityAt` and clears any `ghostedSince` — called by the
  /// snapshot on a today push so the ghost-sweep Cloud Function can detect
  /// 72h-silent members and a returning member un-ghosts immediately.
  Future<void> markActivity(String squadId, String uid) =>
      _memberRef(squadId, uid).set(
          {'lastActivityAt': FieldValue.serverTimestamp(), 'ghostedSince': null},
          SetOptions(merge: true));

  /// Per-squad outgoing "broadcast MY streak losses" toggle (sender opt-out;
  /// the broken-streak Cloud Function honours it).
  Future<void> setBroadcastStreakLoss(String squadId, String uid, bool enabled) =>
      _memberRef(squadId, uid).set({'broadcastStreakLoss': enabled}, SetOptions(merge: true));

  /// Adds the tapper's uid to a ghosted member's mass-nudge bundle (the
  /// `onAggregateNudge` function coordinates a single push to the ghosted user).
  Future<void> checkInOnGhost(String squadId, String dateKey, String ghostedUid, String myUid) =>
      _squads.doc(squadId).collection('ghostChecks').doc(dateKey)
          .collection('aggregateNudges').doc(ghostedUid)
          .set({'nudgerUids': FieldValue.arrayUnion([myUid]), 'count': FieldValue.increment(1)},
              SetOptions(merge: true));

  // ── Group goals ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _groupGoals(String squadId) =>
      _squads.doc(squadId).collection('groupGoals');

  Future<void> createGroupGoal(String squadId, SquadGroupGoal goal) =>
      _groupGoals(squadId).add(goal.toCreateMap());

  Future<void> deleteGroupGoal(String squadId, String goalId) =>
      _groupGoals(squadId).doc(goalId).delete();

  Stream<List<SquadGroupGoal>> watchGroupGoals(String squadId) =>
      _groupGoals(squadId).snapshots().map(
          (qs) => qs.docs.map((d) => SquadGroupGoal.fromMap(d.id, d.data())).toList());

  Future<SquadDayEntry?> getDayEntry(String squadId, String dateKey, String uid) async {
    final d = await _squads.doc(squadId).collection('days').doc(dateKey).collection('entries').doc(uid).get();
    return d.exists ? SquadDayEntry.fromMap(uid, d.data()!) : null;
  }

  /// Transactionally applies [delta] to a member's contribution + currentValue,
  /// stamping hitAt the first time it crosses the target. Idempotent at the call
  /// site (the snapshot passes new−old, so a re-push with the same data is 0).
  Future<void> contributeToGroupGoal(String squadId, String goalId, String uid, double delta) async {
    if (delta == 0) return;
    final ref = _groupGoals(squadId).doc(goalId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final contribs = Map<String, dynamic>.from((data['contributions'] as Map?) ?? {});
      contribs[uid] = ((contribs[uid] as num?)?.toDouble() ?? 0) + delta;
      final target = (data['target'] as num?)?.toDouble() ?? 0;
      final current = (data['currentValue'] as num?)?.toDouble() ?? 0;
      final newVal = current + delta;
      final update = <String, dynamic>{'contributions': contribs, 'currentValue': newVal};
      if (current < target && newVal >= target && data['hitAt'] == null) {
        update['hitAt'] = FieldValue.serverTimestamp();
      }
      tx.update(ref, update);
    });
  }

  // ── Notification prefs (master switches + quiet hours) ──────────────────────

  DocumentReference<Map<String, dynamic>> _notifPrefs(String uid) =>
      _users.doc(uid).collection('notificationPrefs').doc('master');

  Stream<Map<String, dynamic>> watchNotificationPrefs(String uid) =>
      _notifPrefs(uid).snapshots().map((d) => d.data() ?? const <String, dynamic>{});

  Future<void> setNotificationPref(String uid, String key, Object value) =>
      _notifPrefs(uid).set({key: value}, SetOptions(merge: true));

  // ── Activity feed (written by Cloud Functions) ──────────────────────────────

  Stream<List<SquadActivity>> watchActivity(String squadId, {int limit = 20}) =>
      _squads.doc(squadId).collection('activity')
          .orderBy('createdAt', descending: true).limit(limit).snapshots()
          .map((qs) => qs.docs.map((d) => SquadActivity.fromMap(d.id, d.data())).toList());

  // ── Per-day comments ────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _comments(String squadId, String dateKey) =>
      _squads.doc(squadId).collection('days').doc(dateKey).collection('comments');

  Stream<List<SquadComment>> watchComments(String squadId, String dateKey, String toUid) =>
      _comments(squadId, dateKey).where('toUid', isEqualTo: toUid).snapshots().map((qs) {
        final list = qs.docs.map((d) => SquadComment.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
        return list;
      });

  /// Posts a comment in a batch with a per-(from,to,date) counter so the rules'
  /// getAfter rate-limit (≤5/pair/day) can validate it.
  Future<void> addComment(String squadId, String dateKey,
      {required String fromUid, required String fromName, required String toUid, required String text}) async {
    final counter = _squads.doc(squadId).collection('days').doc(dateKey)
        .collection('commentCounters').doc('${fromUid}_$toUid');
    final comment = _comments(squadId, dateKey).doc();
    final batch = _db.batch();
    batch.set(counter, {'count': FieldValue.increment(1), 'fromUid': fromUid, 'toUid': toUid}, SetOptions(merge: true));
    batch.set(comment, {
      'fromUid': fromUid, 'fromName': fromName, 'toUid': toUid,
      'text': text, 'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> editComment(String squadId, String dateKey, String commentId, String text) =>
      _comments(squadId, dateKey).doc(commentId).update({'text': text, 'editedAt': FieldValue.serverTimestamp()});

  /// Soft-delete: keep the doc (preserves rate-limit accounting), blank the text.
  Future<void> deleteComment(String squadId, String dateKey, String commentId) =>
      _comments(squadId, dateKey).doc(commentId).update({'text': '[deleted]', 'deletedAt': FieldValue.serverTimestamp()});

  // ── Weekly intentions ───────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _intentionMembers(String squadId, String weekKey) =>
      _squads.doc(squadId).collection('intentions').doc(weekKey).collection('members');

  Future<void> setIntention(String squadId, String weekKey, SquadIntention intention) =>
      _intentionMembers(squadId, weekKey).doc(intention.uid).set(intention.toMap(), SetOptions(merge: true));

  Stream<List<SquadIntention>> watchIntentions(String squadId, String weekKey) =>
      _intentionMembers(squadId, weekKey).snapshots().map(
          (qs) => qs.docs.map((d) => SquadIntention.fromMap(d.id, d.data())).toList());

  Stream<SquadIntention?> watchMyIntention(String squadId, String weekKey, String uid) =>
      _intentionMembers(squadId, weekKey).doc(uid).snapshots().map(
          (d) => d.exists ? SquadIntention.fromMap(uid, d.data()!) : null);

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

  Future<List<SquadDayEntry>> getDayEntries(String squadId, String dateKey) async {
    final qs = await _entriesCol(squadId, dateKey).get();
    return qs.docs.map((d) => SquadDayEntry.fromMap(d.id, d.data())).toList();
  }

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

  // ── goalsVisible: squad-visible goal occurrences (Phase 6) ───────────────────

  CollectionReference<Map<String, dynamic>> _goalsVisibleCol(String uid) =>
      _users.doc(uid).collection('goalsVisible');

  Future<void> writeGoalVisible(String uid, GoalVisible g) =>
      _goalsVisibleCol(uid).doc(g.id).set(g.toMap());

  Future<void> deleteGoalVisible(String uid, String occId) =>
      _goalsVisibleCol(uid).doc(occId).delete();

  /// Doc ids currently present, so the snapshot pipeline can prune stale ones.
  Future<Set<String>> getGoalVisibleIds(String uid) async {
    final qs = await _goalsVisibleCol(uid).get();
    return qs.docs.map((d) => d.id).toSet();
  }

  /// A squadmate's visible goals that [viewerUid] is allowed to read. The
  /// `readerUids array-contains` filter matches the security rule.
  Stream<List<GoalVisible>> streamSquadmateGoalsVisible(
          String ownerUid, String viewerUid) =>
      _goalsVisibleCol(ownerUid)
          .where('readerUids', arrayContains: viewerUid)
          .snapshots()
          .map((qs) =>
              qs.docs.map((d) => GoalVisible.fromMap(d.id, d.data())).toList());

  // ── goal suggestions (Phase 6) ───────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _suggestionsCol(String squadId) =>
      _squads.doc(squadId).collection('suggestions');

  /// Proposes a goal to [toUid] in [squadId]. Expires after [ttl] (7 days).
  /// Returns the new suggestion doc id.
  Future<String> suggestGoal({
    required String squadId,
    required String fromUid,
    required String fromName,
    required String toUid,
    required String payloadJson,
    Duration ttl = const Duration(days: 7),
    DateTime? now,
  }) async {
    final created = now ?? DateTime.now();
    final ref = await _suggestionsCol(squadId).add({
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'payloadJson': payloadJson,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(created.add(ttl)),
      'status': 'pending',
    });
    return ref.id;
  }

  /// Live pending suggestions addressed to [uid] across all squads (a
  /// collection-group query; needs the composite index in firestore.indexes).
  Stream<List<SquadGoalSuggestion>> streamPendingSuggestionsForMe(String uid,
      {DateTime? now}) {
    final cutoff = Timestamp.fromDate(now ?? DateTime.now());
    return _db
        .collectionGroup('suggestions')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .where('expiresAt', isGreaterThan: cutoff)
        .snapshots()
        .map((qs) => qs.docs.map((d) {
              final squadId = d.reference.parent.parent?.id ?? '';
              return SquadGoalSuggestion.fromDoc(d.id, squadId, d.data());
            }).toList());
  }

  Future<void> setSuggestionStatus(
          String squadId, String suggestionId, String status) =>
      _suggestionsCol(squadId).doc(suggestionId).update({'status': status});

  Future<void> acceptSuggestion(String squadId, String suggestionId) =>
      setSuggestionStatus(squadId, suggestionId, 'accepted');

  Future<void> rejectSuggestion(String squadId, String suggestionId) =>
      setSuggestionStatus(squadId, suggestionId, 'rejected');

  // ── notification queue: morning brief + reminders (Phase 8) ──────────────────
  // The device writes these so the Cloud Functions can send pushes even when the
  // app is closed (the functions can't read the user's local SQLite).

  /// Personal toggle for the morning brief + reminders, read by the functions.
  Future<void> setGoalNotificationsEnabled(String uid, bool enabled) =>
      _users.doc(uid).set({'goalNotificationsEnabled': enabled}, SetOptions(merge: true));

  Future<void> writeTodaysBrief(String uid, String dateKey, Map<String, dynamic> data) =>
      _users.doc(uid).collection('todaysGoalsBrief').doc(dateKey).set(data);

  CollectionReference<Map<String, dynamic>> _pendingRemindersCol(String uid) =>
      _users.doc(uid).collection('pendingReminders');

  Future<void> writePendingReminder(String uid, String occId, Map<String, dynamic> data) =>
      _pendingRemindersCol(uid).doc(occId).set(data);

  Future<void> deletePendingReminder(String uid, String occId) =>
      _pendingRemindersCol(uid).doc(occId).delete();

  Future<Set<String>> getPendingReminderIds(String uid) async {
    final qs = await _pendingRemindersCol(uid).get();
    return qs.docs.map((d) => d.id).toSet();
  }
}
