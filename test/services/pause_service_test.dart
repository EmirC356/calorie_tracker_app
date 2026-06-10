import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/services/pause_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FakeFirebaseFirestore fs;
  late DatabaseService db;
  late PauseService pause;
  final now = DateTime(2026, 6, 10, 9);

  setUp(() async {
    fs = FakeFirebaseFirestore();
    db = DatabaseService(overridePath: inMemoryDatabasePath);
    pause = PauseService(squad: SquadService(firestore: fs), db: db);
    await fs.doc('squads/s1').set({
      'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1'], 'inviteCode': '123456',
    });
    await fs.doc('squads/s1/members/u1').set({'sharingLevel': 'status', 'displayName': 'A'});
  });

  tearDown(() async => db.close());

  test('a valid pause writes the member pause object + a local history row', () async {
    final plan = await pause.declarePause(
        squadId: 's1', uid: 'u1', until: DateTime(2026, 6, 14), reason: 'traveling', now: now);

    expect(plan.ok, isTrue);
    expect(plan.days, 5);

    final m = (await fs.doc('squads/s1/members/u1').get()).data()!;
    expect(m['pause']['active'], isTrue);
    expect(m['pause']['until'], '2026-06-14');
    expect(m['pause']['windowDays'], 5);
    expect(m['pause']['daysUsedThisYear'], 5);
    expect(m['pause']['reason'], 'traveling');

    final history = await db.getPauseHistory();
    expect(history, hasLength(1));
    expect(history.first['squad_id'], 's1');
    expect(history.first['days'], 5);
  });

  test('exceeding the 60-day cap is rejected and writes nothing', () async {
    await fs.doc('squads/s1/members/u1').set({
      'sharingLevel': 'status', 'displayName': 'A',
      'pause': {'active': false, 'daysUsedThisYear': 58, 'windowDays': 0},
    }, SetOptions(merge: true));

    final plan = await pause.declarePause(
        squadId: 's1', uid: 'u1', until: DateTime(2026, 6, 14), now: now); // +5 = 63

    expect(plan.validation, PauseValidation.yearlyCapReached);
    final m = (await fs.doc('squads/s1/members/u1').get()).data()!;
    expect(m['pause']['active'], isFalse); // unchanged
    expect(await db.getPauseHistory(), isEmpty);
  });
}
