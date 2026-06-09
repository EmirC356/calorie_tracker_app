import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late SquadService svc;

  setUp(() {
    fs = FakeFirebaseFirestore();
    svc = SquadService(firestore: fs);
  });

  test('suggestGoal writes a pending suggestion with a 7-day expiry', () async {
    final id = await svc.suggestGoal(
      squadId: 's1',
      fromUid: 'a',
      fromName: 'Alex',
      toUid: 'b',
      payloadJson: '{"title":"Gym 3x"}',
      now: DateTime(2026, 6, 1),
    );
    final snap = await fs.doc('squads/s1/suggestions/$id').get();
    expect(snap.exists, isTrue);
    final d = snap.data()!;
    expect(d['fromUid'], 'a');
    expect(d['toUid'], 'b');
    expect(d['status'], 'pending');
    expect(d['payloadJson'], '{"title":"Gym 3x"}');
  });

  test('streamPendingSuggestionsForMe filters by recipient across squads', () async {
    await svc.suggestGoal(
        squadId: 's1', fromUid: 'a', fromName: 'A', toUid: 'me', payloadJson: '{}', now: DateTime(2026, 6, 1));
    await svc.suggestGoal(
        squadId: 's2', fromUid: 'c', fromName: 'C', toUid: 'someone-else', payloadJson: '{}', now: DateTime(2026, 6, 1));

    final list = await svc.streamPendingSuggestionsForMe('me', now: DateTime(2026, 6, 3)).first;
    expect(list, hasLength(1));
    expect(list.single.squadId, 's1');
    expect(list.single.fromUid, 'a');
  });

  test('accept and reject update the status', () async {
    final id = await svc.suggestGoal(
        squadId: 's1', fromUid: 'a', fromName: 'A', toUid: 'b', payloadJson: '{}');
    await svc.acceptSuggestion('s1', id);
    expect((await fs.doc('squads/s1/suggestions/$id').get()).data()!['status'], 'accepted');

    final id2 = await svc.suggestGoal(
        squadId: 's1', fromUid: 'a', fromName: 'A', toUid: 'b', payloadJson: '{}');
    await svc.rejectSuggestion('s1', id2);
    expect((await fs.doc('squads/s1/suggestions/$id2').get()).data()!['status'], 'rejected');
  });
}
