import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/screens/squad/squad_settings_screen.dart';
import 'package:calorie_tracker_app/widgets/squad/presence_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeFirebaseFirestore> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fs = FakeFirebaseFirestore();
    await fs.doc('squads/s1').set({
      'name': 'Gym', 'ownerUid': 'me', 'memberUids': ['me', 'other'], 'inviteCode': '123456',
    });
    await fs.doc('squads/s1/members/me').set({
      'displayName': 'Me', 'sharingLevel': 'totals', 'lastActivityAt': Timestamp.now(),
    });
    await fs.doc('squads/s1/members/other').set({
      'displayName': 'Other', 'sharingLevel': 'status',
      'lastActivityAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2))),
    });

    final service = SquadService(firestore: fs);
    final authService = AuthService(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
        googleSignIn: GoogleSignIn());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService: authService, squadService: service)),
        ChangeNotifierProvider(create: (_) => SquadProvider(service: service, authService: authService)),
      ],
      child: const MaterialApp(home: Scaffold(body: SquadSettingsScreen(squadId: 's1'))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    return fs;
  }

  testWidgets('segmented sharing control + member recency', (tester) async {
    final fs = await pumpSettings(tester);

    // Segmented control with the three sharing levels.
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Totals'), findsOneWidget);
    expect(find.text('Everything'), findsOneWidget);

    // Member rows show recency, not goal text.
    expect(find.byType(PresenceIndicator), findsWidgets);
    expect(find.text('Active now'), findsWidgets);

    // Selecting "Everything" writes SharingLevel.full to my member doc.
    await tester.tap(find.text('Everything'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final me = await fs.doc('squads/s1/members/me').get();
    expect(me.data()!['sharingLevel'], 'full');
  });
}
