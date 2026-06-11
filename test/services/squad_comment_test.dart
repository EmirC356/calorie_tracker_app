import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late SquadService svc;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    svc = SquadService(firestore: fs);
    await fs.doc('squads/s1').set({
      'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1', 'u2'], 'inviteCode': '123456',
    });
  });

  test('addComment writes the comment + bumps the pair counter', () async {
    await svc.addComment('s1', '2026-06-09',
        fromUid: 'u1', fromName: 'A', toUid: 'u2', text: 'nice work today');

    final list = await svc.watchComments('s1', '2026-06-09', 'u2').first;
    expect(list, hasLength(1));
    expect(list.first.text, 'nice work today');
    expect(list.first.fromUid, 'u1');

    final counter = (await fs.doc('squads/s1/days/2026-06-09/commentCounters/u1_u2').get()).data()!;
    expect(counter['count'], 1);

    // A second comment bumps the same counter.
    await svc.addComment('s1', '2026-06-09', fromUid: 'u1', fromName: 'A', toUid: 'u2', text: 'keep going');
    final counter2 = (await fs.doc('squads/s1/days/2026-06-09/commentCounters/u1_u2').get()).data()!;
    expect(counter2['count'], 2);
  });

  test('soft delete blanks the text and keeps the doc', () async {
    await svc.addComment('s1', '2026-06-09', fromUid: 'u1', fromName: 'A', toUid: 'u2', text: 'oops');
    final c = (await svc.watchComments('s1', '2026-06-09', 'u2').first).first;

    await svc.deleteComment('s1', '2026-06-09', c.id);
    final after = (await svc.watchComments('s1', '2026-06-09', 'u2').first).first;
    expect(after.isDeleted, isTrue);
    expect(after.displayText, '[deleted]');
  });
}
