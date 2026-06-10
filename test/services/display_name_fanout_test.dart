import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  test('updateDisplayName fans out to every squad member doc', () async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('users/u1').set({'displayName': 'Old'});
    await fs.doc('squads/s1').set({'memberUids': ['u1', 'u2'], 'ownerUid': 'u1', 'name': 'S1'});
    await fs.doc('squads/s1/members/u1').set({'displayName': 'Old', 'sharingLevel': 'status'});
    await fs.doc('squads/s2').set({'memberUids': ['u1'], 'ownerUid': 'u1', 'name': 'S2'});
    await fs.doc('squads/s2/members/u1').set({'displayName': 'Old', 'sharingLevel': 'totals'});

    await SquadService(firestore: fs).updateDisplayName('u1', 'New Name');

    expect((await fs.doc('users/u1').get()).data()!['displayName'], 'New Name');
    expect((await fs.doc('squads/s1/members/u1').get()).data()!['displayName'], 'New Name');
    expect((await fs.doc('squads/s2/members/u1').get()).data()!['displayName'], 'New Name');
    // Other fields (sharing level) are preserved by the merge.
    expect((await fs.doc('squads/s1/members/u1').get()).data()!['sharingLevel'], 'status');
  });
}
