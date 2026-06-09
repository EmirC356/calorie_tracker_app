import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  group('SquadService.ensureUserDocument', () {
    test('creates users/{uid} seeded from the Google account on first call', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);
      final user = MockUser(uid: 'u1', displayName: 'Emir', photoURL: 'http://x/p.png');

      final appUser = await svc.ensureUserDocument(user);

      expect(appUser.uid, 'u1');
      expect(appUser.displayName, 'Emir');
      expect(appUser.photoURL, 'http://x/p.png');

      final doc = await fake.collection('users').doc('u1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['displayName'], 'Emir');
      expect(doc.data()!.containsKey('createdAt'), isTrue);
    });

    test('is idempotent — does not overwrite an existing doc', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);
      final user = MockUser(uid: 'u1', displayName: 'Emir');

      await svc.ensureUserDocument(user);
      await fake.collection('users').doc('u1').update({'displayName': 'Renamed'});

      final again = await svc.ensureUserDocument(user);
      expect(again.displayName, 'Renamed'); // returned existing, not re-seeded
    });

    test('falls back to Athlete when the account has no display name', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);
      final user = MockUser(uid: 'u2', displayName: '');

      final appUser = await svc.ensureUserDocument(user);
      expect(appUser.displayName, 'Athlete');
    });

    test('updateDisplayName persists the new name', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);
      final user = MockUser(uid: 'u1', displayName: 'Emir');
      await svc.ensureUserDocument(user);

      await svc.updateDisplayName('u1', 'Captain');

      final reloaded = await svc.getUser('u1');
      expect(reloaded!.displayName, 'Captain');
    });
  });
}
