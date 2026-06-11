import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/photo.dart';
import 'package:calorie_tracker_app/services/photo_service.dart';

void main() {
  // A valid 640×480 JPEG header (SOF0) so readJpegDimensions populates w/h.
  final jpeg = Uint8List.fromList(
      [0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x01, 0xE0, 0x02, 0x80, 0x03, 0, 0, 0]);

  late FakeFirebaseFirestore fs;
  late Map<String, Uint8List> puts;
  late PhotoService service;

  PhotoService make(String uid) {
    puts = {};
    return PhotoService(
      firestore: fs,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
      put: (path, bytes, ct, meta) async => puts[path] = bytes,
    );
  }

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = make('me');
  });

  test('uploadPhoto writes a pending doc + storage object', () async {
    final id = await service.uploadPhoto(squadId: 's1', bytes: jpeg, uploaderName: 'Me');
    final doc = await fs.doc('squads/s1/photos/$id').get();
    final d = doc.data()!;
    expect(d['uploadedByUid'], 'me');
    expect(d['published'], false);
    expect(d['publishedAt'], isNull);
    expect(d['deletedAt'], isNull);
    expect(d['pendingPublishAt'], isNotNull);
    expect(d['width'], 640);
    expect(d['height'], 480);
    expect(puts.keys.single, 'squads/s1/photos/$id.jpg');
  });

  test('upload-then-undo soft-deletes the doc, leaving no orphan + invisible to all', () async {
    final id = await service.uploadPhoto(squadId: 's1', bytes: jpeg, uploaderName: 'Me');
    await service.undoPhoto('s1', id);
    final doc = await fs.doc('squads/s1/photos/$id').get();
    expect(doc.exists, isTrue); // soft delete — doc remains (not orphaned)
    expect(doc.data()!['deletedAt'], isNotNull);
    final photo = Photo.fromMap(id, doc.data()!);
    expect(photo.visibleTo('other'), isFalse); // squadmate never sees it
    expect(photo.visibleTo('me'), isFalse); // deleted → hidden even from uploader
  });

  test('reactToPhoto toggles the composite doc + keeps reactionCounts consistent', () async {
    final id = await service.uploadPhoto(squadId: 's1', bytes: jpeg);
    await service.reactToPhoto(squadId: 's1', photoId: id, emoji: 'fire', fromName: 'Me');
    expect((await fs.doc('squads/s1/photoReactions/${id}_me_fire').get()).exists, isTrue);
    expect(((await fs.doc('squads/s1/photos/$id').get()).data()!['reactionCounts'] as Map)['fire'], 1);

    // Toggling the same emoji again removes the reaction + decrements.
    await service.reactToPhoto(squadId: 's1', photoId: id, emoji: 'fire');
    expect((await fs.doc('squads/s1/photoReactions/${id}_me_fire').get()).exists, isFalse);
    expect(((await fs.doc('squads/s1/photos/$id').get()).data()!['reactionCounts'] as Map)['fire'], 0);
  });

  test('streamForSquad shows published + my own pending, hides others\' pending', () async {
    Map<String, dynamic> base(String uid, bool published) => {
          'uploadedByUid': uid, 'uploadedByName': uid, 'published': published,
          'publishedAt': published ? Timestamp.now() : null, 'deletedAt': null,
          'pendingPublishAt': Timestamp.now(), 'uploadedAt': Timestamp.now(),
          'storagePath': 'x', 'reactionCounts': {'fire': 0, 'flex': 0, 'clap': 0},
        };
    await fs.doc('squads/s1/photos/pub').set(base('other', true));
    await fs.doc('squads/s1/photos/oth_pend').set(base('other', false));
    await fs.doc('squads/s1/photos/my_pend').set(base('me', false));

    var latest = <Photo>[];
    final sub = service.streamForSquad('s1').listen((l) => latest = l);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await sub.cancel();

    final ids = latest.map((p) => p.id).toSet();
    expect(ids.contains('pub'), isTrue);
    expect(ids.contains('my_pend'), isTrue);
    expect(ids.contains('oth_pend'), isFalse);
  });
}
