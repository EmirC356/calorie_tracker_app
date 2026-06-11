import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/services/snapshot_service.dart';

/// Test transformer that tags the entry and can halt the pipeline.
class _Tag extends SnapshotTransformer {
  final String key;
  final bool cont;
  const _Tag(this.key, {this.cont = true});
  @override
  Future<bool> apply(SnapshotContext ctx, Map<String, dynamic> entry) async {
    entry[key] = true;
    return cont;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('pipeline composes transformers in order and a false return halts it', () async {
    final fs = FakeFirebaseFirestore();
    final db = DatabaseService(overridePath: inMemoryDatabasePath);
    final ss = SquadService(firestore: fs);

    await fs.doc('squads/s1').set({
      'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1'],
      'inviteCode': '123456', 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    // Empty goal + totals sharing → a finalized past day is 'missed'.
    await fs.doc('squads/s1/members/u1').set({'sharingLevel': 'totals', 'displayName': 'A'});

    await db.insertMeal(Meal(
      name: 'X', portionGrams: 0,
      nutrients: NutrientInfo(calories: 2000, protein: 0, carbohydrates: 0, fat: 0, fiber: 0, sugar: 0),
      timestamp: DateTime(2026, 6, 8, 12),
    ));

    final snapshot = SnapshotService(
      db: db,
      squadService: ss,
      transformers: const [StatusTransformer(), _Tag('mid'), _Tag('halt', cont: false), _Tag('never')],
    );

    // Push a *past* day so only the entry pipeline runs (no goalVisibility queue).
    await snapshot.pushForUser(uid: 'u1', date: DateTime(2026, 6, 8), now: DateTime(2026, 6, 9, 12));

    final doc = await fs.doc('squads/s1/days/2026-06-08/entries/u1').get();
    final e = doc.data()!;
    expect(e['status'], 'missed');      // StatusTransformer (empty goal, day over)
    expect(e['consumed'], 2000);        // totals sharing level
    expect(e['mid'], isTrue);           // ran
    expect(e['halt'], isTrue);          // ran, then halted
    expect(e.containsKey('never'), isFalse); // skipped after the halt

    await db.close();
  });

  test('a paused member finalizes the day as paused and skips status/totals', () async {
    final fs = FakeFirebaseFirestore();
    final db = DatabaseService(overridePath: inMemoryDatabasePath);
    final ss = SquadService(firestore: fs);

    await fs.doc('squads/s1').set({
      'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1'],
      'inviteCode': '123456', 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await fs.doc('squads/s1/members/u1').set({
      'sharingLevel': 'totals', 'displayName': 'A',
      'pause': {
        'active': true,
        'until': '2026-06-09',
        'declaredAt': Timestamp.fromDate(DateTime(2026, 6, 5)),
        'daysUsedThisYear': 3,
      },
    });
    // Even with logged data, a paused day ignores it.
    await db.insertMeal(Meal(
      name: 'X', portionGrams: 0,
      nutrients: NutrientInfo(calories: 2000, protein: 0, carbohydrates: 0, fat: 0, fiber: 0, sugar: 0),
      timestamp: DateTime(2026, 6, 8, 12),
    ));

    // Default transformers ([PauseTransformer, StatusTransformer]).
    final snapshot = SnapshotService(db: db, squadService: ss);
    await snapshot.pushForUser(uid: 'u1', date: DateTime(2026, 6, 8), now: DateTime(2026, 6, 9, 12));

    final e = (await fs.doc('squads/s1/days/2026-06-08/entries/u1').get()).data()!;
    expect(e['status'], 'paused');
    expect(e['paused'], isTrue);
    expect(e.containsKey('consumed'), isFalse); // status/totals transformer skipped

    await db.close();
  });

  test('a make-up entry redeems a missed day (status stays missed)', () async {
    final fs = FakeFirebaseFirestore();
    final db = DatabaseService(overridePath: inMemoryDatabasePath);
    final ss = SquadService(firestore: fs);

    await fs.doc('squads/s1').set({
      'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1'],
      'inviteCode': '123456', 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    // Goal: burn ≥ 200 kcal. Day 6/8 logged nothing → missed.
    await fs.doc('squads/s1/members/u1').set({
      'sharingLevel': 'status', 'displayName': 'A',
      'goal': {'caloriesBurnedMin': 200},
    });
    // A make-up exercise logged later, tagged for 6/8, satisfies the goal.
    await db.insertExercise(Exercise(
      name: 'Catch-up run', durationMinutes: 30, caloriesBurned: 250,
      timestamp: DateTime(2026, 6, 9, 7), makeupForDate: '2026-06-08'));

    await SnapshotService(db: db, squadService: ss)
        .pushForUser(uid: 'u1', date: DateTime(2026, 6, 8), now: DateTime(2026, 6, 9, 12));

    final e = (await fs.doc('squads/s1/days/2026-06-08/entries/u1').get()).data()!;
    expect(e['status'], 'missed'); // the day itself was still a miss
    expect(e['redeemed'], isTrue); // but rescued by the make-up

    await db.close();
  });

  test('a daily check-in is mirrored onto the day entry', () async {
    final fs = FakeFirebaseFirestore();
    final db = DatabaseService(overridePath: inMemoryDatabasePath);
    final ss = SquadService(firestore: fs);

    await fs.doc('squads/s1').set({
      'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1'],
      'inviteCode': '123456', 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await fs.doc('squads/s1/members/u1').set({'sharingLevel': 'status', 'displayName': 'A'});
    await db.setCheckin('2026-06-08', 'cheatDay');

    await SnapshotService(db: db, squadService: ss)
        .pushForUser(uid: 'u1', date: DateTime(2026, 6, 8), now: DateTime(2026, 6, 9, 12));

    final e = (await fs.doc('squads/s1/days/2026-06-08/entries/u1').get()).data()!;
    expect(e['checkin'], 'cheatDay');

    await db.close();
  });
}
