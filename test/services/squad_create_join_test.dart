import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  group('SquadService create/join', () {
    test('createSquad makes the squad, owner member doc, and code lookup', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);

      final squad = await svc.createSquad(name: 'Grinders', ownerUid: 'owner', random: Random(1));

      expect(squad.name, 'Grinders');
      expect(squad.ownerUid, 'owner');
      expect(squad.memberUids, ['owner']);
      expect(squad.inviteCode.length, 6);

      final member = await fake.collection('squads').doc(squad.id).collection('members').doc('owner').get();
      expect(member.exists, isTrue);
      expect(member.data()!['sharingLevel'], 'status');

      final code = await fake.collection('squadCodes').doc(squad.inviteCode).get();
      expect(code.data()!['squadId'], squad.id);
    });

    test('joinSquadByCode adds a second member', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);
      final squad = await svc.createSquad(name: 'S', ownerUid: 'owner', random: Random(2));

      final joined = await svc.joinSquadByCode(code: squad.inviteCode, uid: 'friend');

      expect(joined.memberUids, containsAll(['owner', 'friend']));
      final member = await fake.collection('squads').doc(squad.id).collection('members').doc('friend').get();
      expect(member.exists, isTrue);
    });

    test('joinSquadByCode rejects bad formats and unknown codes', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);

      expect(() => svc.joinSquadByCode(code: 'abc', uid: 'x'), throwsA(isA<SquadException>()));
      expect(() => svc.joinSquadByCode(code: '000000', uid: 'x'), throwsA(isA<SquadException>()));
    });

    test('joinSquadByCode rejects an expired code', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);
      final squad = await svc.createSquad(name: 'S', ownerUid: 'owner', random: Random(3));
      // Force the code to be expired.
      await fake.collection('squadCodes').doc(squad.inviteCode).update({
        'expiresAt': Timestamp.fromDate(DateTime(2000)),
      });

      expect(() => svc.joinSquadByCode(code: squad.inviteCode, uid: 'late'),
          throwsA(isA<SquadException>()));
    });

    test('regenerateInviteCode swaps the code and disables the old one', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);
      final squad = await svc.createSquad(name: 'S', ownerUid: 'owner', random: Random(4));
      final oldCode = squad.inviteCode;

      final newCode = await svc.regenerateInviteCode(squad.id, random: Random(5));

      expect(newCode, isNot(oldCode));
      final oldDoc = await fake.collection('squadCodes').doc(oldCode).get();
      expect(oldDoc.exists, isFalse, reason: 'old code lookup should be deleted');
      final newDoc = await fake.collection('squadCodes').doc(newCode).get();
      expect(newDoc.data()!['squadId'], squad.id);
    });

    test('watchMySquads streams squads the uid belongs to', () async {
      final fake = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fake);
      await svc.createSquad(name: 'A', ownerUid: 'me', random: Random(6));
      final b = await svc.createSquad(name: 'B', ownerUid: 'other', random: Random(7));
      await svc.joinSquadByCode(code: b.inviteCode, uid: 'me');

      final mine = await svc.watchMySquads('me').first;
      expect(mine.map((s) => s.name), containsAll(['A', 'B']));
    });
  });
}
