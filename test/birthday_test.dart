import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/providers/squad_provider.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/widgets/calendar/birthday_strip.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('age from birthday', () {
    test('effectiveAge derives from the birthday', () {
      final now = DateTime.now();
      final exactly25 = UserProfile(
          heightCm: 180, age: 0, sex: Sex.male, activity: ActivityLevel.moderate,
          goal: DietGoal.maintain, birthday: _ymd(DateTime(now.year - 25, now.month, now.day)));
      expect(exactly25.effectiveAge, 25);
      // A birthday that hasn't occurred yet this year is one younger.
      final notYet = exactly25.copyWith(
          birthday: _ymd(DateTime(now.year - 25, now.month, now.day).add(const Duration(days: 1))));
      expect(notYet.effectiveAge, 24);
    });

    test('falls back to the manual age when no birthday', () {
      const p = UserProfile(
          heightCm: 180, age: 33, sex: Sex.male, activity: ActivityLevel.moderate, goal: DietGoal.maintain);
      expect(p.effectiveAge, 33);
    });
  });

  group('syncBirthdayEvent', () {
    test('writes a non-graded event with the squad audience, then clears it', () async {
      final fs = FakeFirebaseFirestore();
      final svc = SquadService(firestore: fs);
      await fs.doc('squads/s1').set({
        'name': 'S', 'ownerUid': 'u1', 'memberUids': ['u1', 'u2'], 'inviteCode': '123456',
      });

      await svc.syncBirthdayEvent('u1', month: 3, day: 14, displayName: 'Emir');
      final d = (await fs.doc('users/u1/goalsVisible/birthday_03-14').get()).data()!;
      expect(d['type'], 'event');
      expect(d['subtype'], 'birthday');
      expect(d['month'], 3);
      expect(d['day'], 14);
      expect((d['readerUids'] as List), containsAll(['u1', 'u2']));

      // Clearing removes the event.
      await svc.syncBirthdayEvent('u1');
      expect((await fs.doc('users/u1/goalsVisible/birthday_03-14').get()).exists, isFalse);
    });
  });

  testWidgets('BirthdayStrip shows a squadmate birthday on the matching day', (tester) async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('users/u2/goalsVisible/birthday_03-14').set({
      'ownerUid': 'u2', 'type': 'event', 'subtype': 'birthday', 'month': 3, 'day': 14,
      'displayName': 'Selin', 'readerUids': ['u1', 'u2'], 'squadIds': ['s1'],
    });
    final service = SquadService(firestore: fs);

    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SquadProvider(service: service))],
      child: MaterialApp(
        home: Scaffold(body: BirthdayStrip(viewerUid: 'u1', date: DateTime(2026, 3, 14))),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.textContaining("Selin's birthday"), findsOneWidget);
  });
}
