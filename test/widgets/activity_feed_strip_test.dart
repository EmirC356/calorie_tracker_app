import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/providers/activity_feed_provider.dart';
import 'package:calorie_tracker_app/providers/squad_provider.dart';
import 'package:calorie_tracker_app/services/auth_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/widgets/squad/activity_feed_strip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> seed(FakeFirebaseFirestore fs, List<Map<String, dynamic>> events) async {
    await fs.doc('squads/s1').set({'name': 'S', 'ownerUid': 'me', 'memberUids': ['me'], 'inviteCode': '123456'});
    for (var i = 0; i < events.length; i++) {
      await fs.doc('squads/s1/activity/a$i').set({
        ...events[i],
        'createdAt': Timestamp.fromDate(DateTime(2026, 6, 15, 12, i)),
      });
    }
  }

  Future<void> pumpStrip(WidgetTester tester, FakeFirebaseFirestore fs) async {
    final service = SquadService(firestore: fs);
    final authService = AuthService(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
        googleSignIn: GoogleSignIn());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SquadProvider(service: service, authService: authService)),
        ChangeNotifierProvider(create: (_) => ActivityFeedProvider(service: service, authService: authService)),
      ],
      child: const MaterialApp(home: Scaffold(body: ActivityFeedStrip(squadId: 's1'))),
    ));
    await tester.pump(); // postFrame bind
    await tester.pump(const Duration(milliseconds: 150)); // stream emit
  }

  testWidgets('renders a single event line', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, [{'type': 'goalHit', 'actorUid': 'u2', 'actorName': 'Selin', 'payload': {}}]);
    await pumpStrip(tester, fs);
    expect(find.text('Selin hit their goal'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // dispose cycle timer
  });

  testWidgets('renders nothing when there are no events', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, const []);
    await pumpStrip(tester, fs);
    expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with 3 events shows the latest, opens the sheet, and filters by type', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, [
      {'type': 'goalHit', 'actorUid': 'u2', 'actorName': 'Selin', 'payload': {}},
      {'type': 'commentPosted', 'actorUid': 'u2', 'actorName': 'Selin', 'subjectName': 'Ali', 'payload': {}},
      {'type': 'goalHit', 'actorUid': 'u3', 'actorName': 'Ali', 'payload': {}},
    ]);
    await pumpStrip(tester, fs);
    // Latest (a2, Ali goalHit) shows first.
    expect(find.text('Ali hit their goal'), findsOneWidget);

    // Open the expanded sheet.
    await tester.tap(find.byIcon(LucideIcons.chevronRight));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SQUAD ACTIVITY'), findsOneWidget);
    expect(find.text("Selin commented on Ali's day"), findsOneWidget);
    // The sheet (unfiltered) also lists Selin's goalHit — which the strip never
    // shows (the strip is on the latest, Ali's).
    expect(find.text('Selin hit their goal'), findsOneWidget);

    // Filter to Comments → the sheet's goalHit row drops out.
    await tester.tap(find.text('Comments'));
    await tester.pump();
    expect(find.text("Selin commented on Ali's day"), findsOneWidget);
    expect(find.text('Selin hit their goal'), findsNothing);

    await tester.pumpWidget(const SizedBox()); // dispose
  });
}
