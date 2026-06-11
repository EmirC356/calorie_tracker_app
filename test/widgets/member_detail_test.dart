import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/providers/auth_provider.dart';
import 'package:calorie_tracker_app/providers/squad_provider.dart';
import 'package:calorie_tracker_app/services/auth_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/screens/squad/member_day_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpDetail(WidgetTester tester, SquadMember member, SquadDayEntry? entry) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeFirebaseFirestore();
    final authService = AuthService(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
        googleSignIn: GoogleSignIn());
    final service = SquadService(firestore: fs);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService: authService, squadService: service)),
        ChangeNotifierProvider(create: (_) => SquadProvider(service: service, authService: authService)),
      ],
      child: MaterialApp(
        home: MemberDayDetailScreen(member: member, entry: entry, squadId: 's1', dateKey: '2026-06-15'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('full-sharing day: collapsed stats drop BURNED, EXERCISE is composite', (tester) async {
    const member = SquadMember(
        uid: 'other', displayName: 'Ana',
        goal: SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2000));
    const entry = SquadDayEntry(
      uid: 'other', status: GoalStatus.hit,
      consumed: 1800, burned: 300, exerciseMinutes: 45,
      meals: [EntryMeal(name: 'Lunch', kcal: 600)],
      exercises: [EntryExercise(name: 'Run', minutes: 30, kcal: 300)],
    );
    await pumpDetail(tester, member, entry);

    expect(find.text('CONSUMED'), findsOneWidget);
    expect(find.text('EXERCISE'), findsOneWidget);
    expect(find.text('BURNED'), findsNothing); // burned column dropped
    expect(find.text('min · 300 kcal'), findsOneWidget); // composite exercise stat
    // Primary reaction bar renders the nudge glyphs.
    expect(find.text('🔥'), findsWidgets);
    // Meal + exercise timelines present (full sharing).
    expect(find.text('MEALS'), findsOneWidget);
    expect(find.text('EXERCISES'), findsOneWidget);
  });

  testWidgets('status-only member: no stat row, shows the status note', (tester) async {
    const member = SquadMember(
        uid: 'other', displayName: 'Bo',
        goal: SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2000));
    const entry = SquadDayEntry(uid: 'other', status: GoalStatus.inProgress); // no totals
    await pumpDetail(tester, member, entry);

    expect(find.text('CONSUMED'), findsNothing);
    expect(find.textContaining('shares only their status'), findsOneWidget);
  });

  testWidgets('CONSUMED hidden when the member has no calorie goal', (tester) async {
    const member = SquadMember(
        uid: 'other', displayName: 'Cy',
        goal: SquadGoal(exerciseMinutesMin: 30)); // exercise-only goal
    const entry = SquadDayEntry(uid: 'other', status: GoalStatus.hit, exerciseMinutes: 40, burned: 250);
    await pumpDetail(tester, member, entry);

    expect(find.text('CONSUMED'), findsNothing);
    expect(find.text('EXERCISE'), findsOneWidget);
  });
}
