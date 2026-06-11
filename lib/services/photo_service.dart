import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/photo.dart';
import 'image_compression.dart' as img;

/// Storage write port — abstracted so the service is unit-testable with fake
/// Firestore + an in-memory storage fake (no native Firebase). The client only
/// ever WRITES to Storage; deletion (undo reap) is the Cloud Function's job.
typedef StoragePut = Future<void> Function(
    String path, Uint8List bytes, String contentType, Map<String, String> metadata);

/// All Firestore + Storage IO for the Proof feature. Screens never touch this
/// directly — they go through [PhotoProvider].
class PhotoService {
  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;
  final StoragePut _put;

  final Future<String> Function(String path) _resolveUrl;

  PhotoService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    StoragePut? put,
    Future<String> Function(String path)? resolveUrl,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _put = put ?? _defaultPut(storage),
        _resolveUrl = resolveUrl ?? _defaultResolve(storage);

  static StoragePut _defaultPut(FirebaseStorage? storage) {
    return (path, bytes, contentType, metadata) async {
      final s = storage ?? FirebaseStorage.instance;
      await s.ref(path).putData(
          bytes, SettableMetadata(contentType: contentType, customMetadata: metadata));
    };
  }

  static Future<String> Function(String) _defaultResolve(FirebaseStorage? storage) =>
      (path) async => (storage ?? FirebaseStorage.instance).ref(path).getDownloadURL();

  /// Resolves a Storage object path to a download URL (token-authenticated).
  Future<String> downloadUrl(String path) => _resolveUrl(path);

  CollectionReference<Map<String, dynamic>> _photos(String squadId) =>
      _fs.collection('squads/$squadId/photos');
  CollectionReference<Map<String, dynamic>> _reactions(String squadId) =>
      _fs.collection('squads/$squadId/photoReactions');

  String get _uid => _auth.currentUser?.uid ?? '';

  /// A fresh photo id, so the optimistic placeholder and the eventual doc share
  /// the same id (for reconciliation).
  String newPhotoId(String squadId) => _photos(squadId).doc().id;

  Future<Uint8List> compressForUpload(Uint8List rawBytes) =>
      img.compressJpeg(rawBytes, maxDim: 1920, quality: 80);

  /// Uploads the (already-compressed) [bytes] to Storage, then writes the
  /// Firestore doc with `published: false` + a 60s `pendingPublishAt`. Storage
  /// is written first so the doc never references a missing object. Returns the
  /// generated photoId.
  Future<String> uploadPhoto({
    required String squadId,
    required Uint8List bytes,
    PhotoGoalRef? goalRef,
    String? uploaderName,
    String? uploaderPhotoURL,
    String? photoId,
  }) async {
    final uid = _uid;
    final ref = photoId != null ? _photos(squadId).doc(photoId) : _photos(squadId).doc();
    final id = ref.id;
    final storagePath = 'squads/$squadId/photos/$id.jpg';
    final dims = img.readJpegDimensions(bytes);

    await _put(storagePath, bytes, 'image/jpeg', {'uploadedByUid': uid});
    await ref.set({
      'uploadedByUid': uid,
      'uploadedByName': uploaderName ?? '',
      'uploadedByPhotoURL': uploaderPhotoURL ?? '',
      'storagePath': storagePath,
      'width': dims?.width ?? 0,
      'height': dims?.height ?? 0,
      'uploadedAt': FieldValue.serverTimestamp(),
      'publishedAt': null,
      'published': false,
      'pendingPublishAt': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 60))),
      if (goalRef != null) 'goalRef': goalRef.toMap(),
      'reactionCounts': {'fire': 0, 'flex': 0, 'clap': 0},
      'deletedAt': null,
    });
    return id;
  }

  /// Undo within the 60s window: soft-delete a still-pending photo. The Cloud
  /// Function reaps the Storage object (a clean memory hole — no push/feed).
  Future<void> undoPhoto(String squadId, String photoId) =>
      _photos(squadId).doc(photoId).update({'deletedAt': FieldValue.serverTimestamp()});

  /// Soft-delete an already-published photo (owner only, enforced by rules).
  Future<void> deletePhoto(String squadId, String photoId) =>
      _photos(squadId).doc(photoId).update({'deletedAt': FieldValue.serverTimestamp()});

  /// Toggle a reaction: the composite-id doc enforces one-per-(user,emoji,photo).
  /// The denormalized `reactionCounts` aggregate is kept consistent in the same
  /// transaction.
  Future<void> reactToPhoto({
    required String squadId,
    required String photoId,
    required String emoji,
    String? fromName,
  }) async {
    final uid = _uid;
    final reactionRef = _reactions(squadId).doc('${photoId}_${uid}_$emoji');
    final photoRef = _photos(squadId).doc(photoId);
    await _fs.runTransaction((tx) async {
      final existing = await tx.get(reactionRef);
      final photoSnap = await tx.get(photoRef);
      final raw = (photoSnap.data()?['reactionCounts'] as Map?)?.cast<String, dynamic>() ?? const {};
      final counts = <String, int>{
        'fire': (raw['fire'] as num?)?.toInt() ?? 0,
        'flex': (raw['flex'] as num?)?.toInt() ?? 0,
        'clap': (raw['clap'] as num?)?.toInt() ?? 0,
      };
      if (existing.exists) {
        tx.delete(reactionRef);
        counts[emoji] = (counts[emoji]! - 1).clamp(0, 1 << 30);
      } else {
        tx.set(reactionRef, {
          'photoId': photoId,
          'fromUid': uid,
          'fromName': fromName ?? '',
          'emoji': emoji,
          'createdAt': FieldValue.serverTimestamp(),
        });
        counts[emoji] = counts[emoji]! + 1;
      }
      tx.update(photoRef, {'reactionCounts': counts});
    });
  }

  /// Which emojis the current user has reacted with on [photoId].
  Stream<Set<String>> streamMyReactions(String squadId, String photoId) {
    final uid = _uid;
    return _reactions(squadId)
        .where('photoId', isEqualTo: photoId)
        .where('fromUid', isEqualTo: uid)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()['emoji'] as String).toSet());
  }

  /// Reactors for one emoji on a photo (for the reactor sheet), newest first.
  Stream<List<Map<String, dynamic>>> streamReactors(String squadId, String photoId, String emoji) {
    return _reactions(squadId)
        .where('photoId', isEqualTo: photoId)
        .where('emoji', isEqualTo: emoji)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList()
          ..sort((a, b) => ((b['createdAt'] as Timestamp?) ?? Timestamp(0, 0))
              .compareTo((a['createdAt'] as Timestamp?) ?? Timestamp(0, 0))));
  }

  // ── Visibility queries (rules-compatible) ──────────────────────────────────
  // A single OR query (published || mine) can't be gated by Firestore rules, so
  // visibility is two queries merged client-side. Both filter deletedAt==null.
  Stream<List<Photo>> streamPublished(String squadId, {int limit = 30}) => _photos(squadId)
      .where('published', isEqualTo: true)
      .where('deletedAt', isNull: true)
      .orderBy('uploadedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((qs) => qs.docs.map((d) => Photo.fromMap(d.id, d.data())).toList());

  Stream<List<Photo>> streamMine(String squadId, String uid, {int limit = 30}) => _photos(squadId)
      .where('uploadedByUid', isEqualTo: uid)
      .where('deletedAt', isNull: true)
      .orderBy('uploadedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((qs) => qs.docs.map((d) => Photo.fromMap(d.id, d.data())).toList());

  /// Combined visible stream: published + my own (incl. pending), deduped and
  /// sorted by uploadedAt desc.
  Stream<List<Photo>> streamForSquad(String squadId, {int limit = 30}) =>
      _combineLatest(streamPublished(squadId, limit: limit), streamMine(squadId, _uid, limit: limit));

  Stream<List<Photo>> _combineLatest(Stream<List<Photo>> a, Stream<List<Photo>> b) {
    List<Photo>? latestA, latestB;
    StreamSubscription<List<Photo>>? sa, sb;
    late StreamController<List<Photo>> ctrl;
    void emit() {
      if (latestA == null && latestB == null) return;
      final byId = <String, Photo>{};
      for (final p in [...?latestA, ...?latestB]) {
        byId[p.id] = p;
      }
      final list = byId.values.toList()
        ..sort((x, y) => (y.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(x.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      ctrl.add(list);
    }

    ctrl = StreamController<List<Photo>>(
      onListen: () {
        sa = a.listen((v) {
          latestA = v;
          emit();
        }, onError: ctrl.addError);
        sb = b.listen((v) {
          latestB = v;
          emit();
        }, onError: ctrl.addError);
      },
      onCancel: () async {
        await sa?.cancel();
        await sb?.cancel();
      },
    );
    return ctrl.stream;
  }
}
