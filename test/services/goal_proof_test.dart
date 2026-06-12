import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/services/database_service.dart';
import 'package:calorie_tracker_app/services/goal_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('finishWithProof persists done + proof refs; undo reverts + clears', () async {
    final db = DatabaseService(overridePath: inMemoryDatabasePath);
    final goals = GoalService(db: db);
    final id = await goals.createGoal(Goal(
      title: 'Read 30 min',
      category: GoalCategory.health,
      color: const Color(0xFF22C55E),
      startDate: DateTime(2026, 6, 12),
      createdAt: DateTime(2026, 6, 1),
    ));
    final date = DateTime(2026, 6, 12);

    // Finish with two-squad proof.
    await goals.setOccurrenceStatus(
      goalId: id, date: date, status: OccurrenceStatus.done,
      proofPhotoIds: [
        {'squadId': 's1', 'photoId': 'p1'},
        {'squadId': 's2', 'photoId': 'p2'},
      ],
    );
    var occ = await goals.getOccurrence(id, date);
    expect(occ!.status, OccurrenceStatus.done);
    expect(occ.doneAt, isNotNull);
    expect(occ.hasProof, isTrue);
    expect(occ.proofPhotoIds!.length, 2);
    expect(occ.proofPhotoIds!.first['photoId'], 'p1');

    // Undo → open + proof cleared.
    await goals.setOccurrenceStatus(
        goalId: id, date: date, status: OccurrenceStatus.open, clearProof: true);
    occ = await goals.getOccurrence(id, date);
    expect(occ!.status, OccurrenceStatus.open);
    expect(occ.doneAt, isNull);
    expect(occ.proofPhotoIds, isNull);

    await db.close();
  });
}
