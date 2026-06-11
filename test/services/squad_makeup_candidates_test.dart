import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  test('findMakeupCandidates returns only un-redeemed, non-paused missed days', () async {
    final fs = FakeFirebaseFirestore();
    final svc = SquadService(firestore: fs);
    final now = DateTime(2026, 6, 10, 12); // today

    await fs.doc('squads/s1').set({
      'name': 'Gym Bros', 'ownerUid': 'u1', 'memberUids': ['u1'], 'inviteCode': '123456',
    });
    // Yesterday (6/9): missed, not redeemed → a candidate.
    await fs.doc('squads/s1/days/2026-06-09/entries/u1').set({'status': 'missed'});
    // 2 days ago (6/8): missed but already redeemed → NOT a candidate.
    await fs.doc('squads/s1/days/2026-06-08/entries/u1').set({'status': 'missed', 'redeemed': true});

    final candidates = await svc.findMakeupCandidates('u1', now: now);
    expect(candidates, hasLength(1));
    expect(candidates.first.date, '2026-06-09');
    expect(candidates.first.squadName, 'Gym Bros');
  });

  test('a paused missed day is not a make-up candidate', () async {
    final fs = FakeFirebaseFirestore();
    final svc = SquadService(firestore: fs);
    final now = DateTime(2026, 6, 10, 12);

    await fs.doc('squads/s1').set({
      'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1'], 'inviteCode': '123456',
    });
    await fs.doc('squads/s1/days/2026-06-09/entries/u1').set({'status': 'paused', 'paused': true});

    final candidates = await svc.findMakeupCandidates('u1', now: now);
    expect(candidates, isEmpty);
  });
}
