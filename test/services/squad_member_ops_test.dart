import 'dart:math';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/squad_goal.dart';
import 'package:calorie_tracker_app/models/squad_member.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  group('SquadService member + owner ops', () {
    late FakeFirebaseFirestore fake;
    late SquadService svc;

    setUp(() {
      fake = FakeFirebaseFirestore();
      svc = SquadService(firestore: fake);
    });

    test('updateGoal and updateSharingLevel persist on the member doc', () async {
      final squad = await svc.createSquad(name: 'S', ownerUid: 'owner', displayName: 'Owner', random: Random(1));

      await svc.updateGoal(squad.id, 'owner',
          const SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2100));
      await svc.updateSharingLevel(squad.id, 'owner', SharingLevel.full);

      final m = await svc.watchMember(squad.id, 'owner').first;
      expect(m!.goal.calorieTarget, 2100);
      expect(m.goal.calorieMode, CalorieMode.cap);
      expect(m.sharingLevel, SharingLevel.full);
      expect(m.displayName, 'Owner'); // denormalized name survives merges
    });

    test('leaveSquad removes the member from memberUids and deletes their doc', () async {
      final squad = await svc.createSquad(name: 'S', ownerUid: 'owner', random: Random(2));
      await svc.joinSquadByCode(code: squad.inviteCode, uid: 'friend', displayName: 'Friend');

      await svc.leaveSquad(squad.id, 'friend');

      final reloaded = await svc.getSquad(squad.id);
      expect(reloaded!.memberUids, isNot(contains('friend')));
      final memberDoc = await fake.collection('squads').doc(squad.id).collection('members').doc('friend').get();
      expect(memberDoc.exists, isFalse);
    });

    test('kickMember (owner) removes a member', () async {
      final squad = await svc.createSquad(name: 'S', ownerUid: 'owner', random: Random(3));
      await svc.joinSquadByCode(code: squad.inviteCode, uid: 'friend');

      await svc.kickMember(squad.id, 'friend');

      final reloaded = await svc.getSquad(squad.id);
      expect(reloaded!.memberUids, isNot(contains('friend')));
    });

    test('transferOwnership changes the owner', () async {
      final squad = await svc.createSquad(name: 'S', ownerUid: 'owner', random: Random(4));
      await svc.joinSquadByCode(code: squad.inviteCode, uid: 'friend');

      await svc.transferOwnership(squad.id, 'friend');

      final reloaded = await svc.getSquad(squad.id);
      expect(reloaded!.ownerUid, 'friend');
    });

    test('deleteSquad removes squad, members, and the code lookup', () async {
      final squad = await svc.createSquad(name: 'S', ownerUid: 'owner', random: Random(5));
      await svc.joinSquadByCode(code: squad.inviteCode, uid: 'friend');

      await svc.deleteSquad(squad.id);

      expect(await svc.getSquad(squad.id), isNull);
      final code = await fake.collection('squadCodes').doc(squad.inviteCode).get();
      expect(code.exists, isFalse);
      final members = await fake.collection('squads').doc(squad.id).collection('members').get();
      expect(members.docs, isEmpty);
    });
  });
}
