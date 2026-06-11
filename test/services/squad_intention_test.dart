import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  test('isoWeekKey is Monday-anchored and stable across a week', () {
    final mon = DateTime(2026, 6, 8); // a Monday
    final sun = DateTime(2026, 6, 14);
    expect(isoWeekKey(mon), isoWeekKey(sun));
    expect(isoWeekKey(mon), matches(r'^\d{4}-W\d{2}$'));
    // The next Monday rolls to a new week.
    expect(isoWeekKey(DateTime(2026, 6, 15)), isNot(isoWeekKey(mon)));
  });

  test('setIntention writes the member doc; watchMyIntention reads it back', () async {
    final fs = FakeFirebaseFirestore();
    final svc = SquadService(firestore: fs);
    const week = '2026-W24';

    await svc.setIntention('s1', week, const SquadIntention(uid: 'u1', text: 'Gym 3x'));

    final mine = await svc.watchMyIntention('s1', week, 'u1').first;
    expect(mine, isNotNull);
    expect(mine!.text, 'Gym 3x');
    expect(mine.gradedStatus, 'unset');

    final all = await svc.watchIntentions('s1', week).first;
    expect(all, hasLength(1));
    expect(all.first.uid, 'u1');
  });
}
