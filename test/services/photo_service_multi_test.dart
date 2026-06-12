import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/photo_service.dart';

void main() {
  final jpeg = Uint8List.fromList(
      [0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x01, 0xE0, 0x02, 0x80, 0x03, 0, 0, 0]);

  late FakeFirebaseFirestore fs;
  late PhotoService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = PhotoService(
      firestore: fs,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
      put: (path, bytes, ct, meta) async {},
    );
  });

  for (final n in [1, 2, 3]) {
    test('uploadPhotoToSquads N=$n creates $n linked, published sibling docs', () async {
      final squadIds = [for (var i = 0; i < n; i++) 's$i'];
      final r = await service.uploadPhotoToSquads(squadIds: squadIds, bytes: jpeg, uploaderName: 'Me');

      expect(r.uploaded.length, n);
      expect(r.failedSquadIds, isEmpty);
      expect(r.successCount, n);
      expect(r.siblingGroupId, isNotEmpty);
      for (final u in r.uploaded) {
        final d = (await fs.doc('squads/${u.squadId}/photos/${u.photoId}').get()).data()!;
        expect(d['siblingGroupId'], r.siblingGroupId);
        expect((d['siblingSquadIds'] as List).cast<String>().toSet(), squadIds.toSet());
        expect(d['published'], true);
        expect(d['uploadedByUid'], 'me');
      }
    });
  }

  test('deleteSiblingGroup cascades soft-delete to every sibling', () async {
    final r = await service.uploadPhotoToSquads(squadIds: ['s0', 's1', 's2'], bytes: jpeg);
    await service.deleteSiblingGroup(r.siblingGroupId);
    for (final u in r.uploaded) {
      final d = (await fs.doc('squads/${u.squadId}/photos/${u.photoId}').get()).data()!;
      expect(d['deletedAt'], isNotNull);
    }
  });

  test('deleteSiblingGroup only touches the current user\'s docs', () async {
    final r = await service.uploadPhotoToSquads(squadIds: ['s0'], bytes: jpeg);
    // A different user's photo in the same (forged) group must not be deleted.
    await fs.doc('squads/s0/photos/other').set({
      'uploadedByUid': 'someone', 'siblingGroupId': r.siblingGroupId, 'deletedAt': null,
    });
    await service.deleteSiblingGroup(r.siblingGroupId);
    expect((await fs.doc('squads/s0/photos/other').get()).data()!['deletedAt'], isNull);
  });

  test('reactToPhotoCascade toggles the reaction on every sibling', () async {
    final r = await service.uploadPhotoToSquads(squadIds: ['s0', 's1'], bytes: jpeg);
    await service.reactToPhotoCascade(siblingGroupId: r.siblingGroupId, emoji: 'fire', fromName: 'Me');
    for (final u in r.uploaded) {
      final p = (await fs.doc('squads/${u.squadId}/photos/${u.photoId}').get()).data()!;
      expect((p['reactionCounts'] as Map)['fire'], 1);
      expect((await fs.doc('squads/${u.squadId}/photoReactions/${u.photoId}_me_fire').get()).exists, isTrue);
    }
    // Toggle off across the group.
    await service.reactToPhotoCascade(siblingGroupId: r.siblingGroupId, emoji: 'fire');
    for (final u in r.uploaded) {
      final p = (await fs.doc('squads/${u.squadId}/photos/${u.photoId}').get()).data()!;
      expect((p['reactionCounts'] as Map)['fire'], 0);
      expect((await fs.doc('squads/${u.squadId}/photoReactions/${u.photoId}_me_fire').get()).exists, isFalse);
    }
  });
}
