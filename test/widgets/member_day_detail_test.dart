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

  Future<void> pumpDetail(WidgetTester tester, {required SquadMember member, SquadDayEntry? entry}) async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('squads/s1').set({'name': 'S', 'ownerUid': 'me', 'memberUids': ['me'], 'inviteCode': '123456'});
    final service = SquadService(firestore: fs);
    final authService = AuthService(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me', displayName: 'Me')),
        googleSignIn: GoogleSignIn());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService: authService, squadService: service)),
        ChangeNotifierProvider(create: (_) => SquadProvider(service: service, authService: authService)),
      ],
      child: MaterialApp(
        home: MemberDayDetailScreen(member: member, entry: entry, squadId: 's1', dateKey: '2026-06-11'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the primary profile calorie goal with a status pill', (tester) async {
    const member = SquadMember(
      uid: 'them', displayName: 'Selin', inheritedFromProfile: true,
      profileGoalSnapshot: ProfileGoalSnapshot(calorieMode: CalorieMode.cap, calorieTarget: 2200),
    );
    const entry = SquadDayEntry(uid: 'them', status: GoalStatus.inProgress);
    await pumpDetail(tester, member: member, entry: entry);

    expect(find.text("TODAY'S GOALS"), findsOneWidget);
    expect(find.text('≤ 2200 kcal/day'), findsWidgets);
  });

  testWidgets('renders the exercise goal title', (tester) async {
    const member = SquadMember(
      uid: 'them', displayName: 'Selin', inheritedFromProfile: true,
      profileGoalSnapshot: ProfileGoalSnapshot(weeklyExerciseSessions: 3, minSessionMinutes: 20),
    );
    await pumpDetail(tester, member: member, entry: const SquadDayEntry(uid: 'them', status: GoalStatus.inProgress));
    expect(find.text('3 sessions/week (≥ 20 min)'), findsWidgets);
  });

  testWidgets('shows empty state when no profile goal and no calendar goals', (tester) async {
    const member = SquadMember(uid: 'them', displayName: 'Selin', inheritedFromProfile: true);
    await pumpDetail(tester, member: member, entry: null);
    expect(find.text('No goals shared today'), findsOneWidget);
    expect(find.text("TODAY'S GOALS"), findsNothing);
  });
}
