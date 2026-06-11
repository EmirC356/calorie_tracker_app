import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/providers/auth_provider.dart';
import 'package:calorie_tracker_app/providers/squad_provider.dart';
import 'package:calorie_tracker_app/services/auth_service.dart';
import 'package:calorie_tracker_app/services/snapshot_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/screens/squad/squad_board_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('bars are proportional to streak; own row marked (you)', (tester) async {
    final fs = FakeFirebaseFirestore();
    final now = DateTime.now();
    String key(DateTime d) => SnapshotService.dateKey(d);
    await fs.doc('squads/s1').set({'name': 'S', 'ownerUid': 'a', 'memberUids': ['a', 'b'], 'inviteCode': '123456'});
    await fs.doc('squads/s1/members/a').set({'displayName': 'Alpha', 'sharingLevel': 'status'});
    await fs.doc('squads/s1/members/b').set({'displayName': 'Bravo', 'sharingLevel': 'status'});
    // A: a 3-day streak (today + the two prior). B: just today.
    for (final d in [0, 1, 2]) {
      await fs.doc('squads/s1/days/${key(now.subtract(Duration(days: d)))}/entries/a')
          .set({'uid': 'a', 'status': 'hit'});
    }
    await fs.doc('squads/s1/days/${key(now)}/entries/b').set({'uid': 'b', 'status': 'hit'});

    final service = SquadService(firestore: fs);
    final authService = AuthService(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'a')),
        googleSignIn: GoogleSignIn());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService: authService, squadService: service)),
        ChangeNotifierProvider(create: (_) => SquadProvider(service: service, authService: authService)),
      ],
      child: const MaterialApp(home: Scaffold(body: SquadBoardTab(squadId: 's1'))),
    ));
    await tester.pump(); // initState → _load
    await tester.pump(const Duration(milliseconds: 400)); // _load resolves + setState

    // Own row labelled, sorted A (streak 3) above B (streak 1).
    expect(find.text('Alpha (you)'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);

    // Two proportional bars: the leader's bar is full; the next is shorter.
    final boxes = tester.widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox)).toList();
    expect(boxes.length, 2);
    expect(boxes[0].widthFactor, 1.0);
    expect(boxes[1].widthFactor, lessThan(1.0));
    expect(boxes[1].widthFactor, greaterThan(0.0));
  });
}
