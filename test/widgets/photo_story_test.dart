import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/providers/auth_provider.dart';
import 'package:calorie_tracker_app/providers/photo_provider.dart';
import 'package:calorie_tracker_app/services/auth_service.dart';
import 'package:calorie_tracker_app/services/photo_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/screens/squad/photo_story_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpStory(WidgetTester tester, FakeFirebaseFirestore fs,
      {required String uploaderUid, required String name}) async {
    await fs.doc('squads/s1').set({'name': 'S', 'ownerUid': 'me', 'memberUids': ['me'], 'inviteCode': '123456'});
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me'));
    final service = PhotoService(firestore: fs, auth: auth, put: (a, b, c, d) async {},
        resolveUrl: (p) async => 'https://example.test/$p');
    final authService = AuthService(auth: auth, googleSignIn: GoogleSignIn());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService: authService, squadService: SquadService(firestore: fs))),
        ChangeNotifierProvider(create: (_) => PhotoProvider(service: service, authService: authService)),
      ],
      child: MaterialApp(home: PhotoStoryViewer(squadId: 's1', uploaderUid: uploaderUid, name: name)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  Map<String, dynamic> photo(String uid, int minute) => {
        'uploadedByUid': uid, 'uploadedByName': uid, 'published': true,
        'publishedAt': Timestamp.now(), 'deletedAt': null,
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 6, 12, 12, minute)),
        'storagePath': 'x', 'reactionCounts': {'fire': 0, 'flex': 0, 'clap': 0},
      };

  testWidgets('shows the member name when they have photos', (tester) async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('squads/s1/photos/a1').set(photo('alice', 1));
    await fs.doc('squads/s1/photos/a2').set(photo('alice', 2));
    await pumpStory(tester, fs, uploaderUid: 'alice', name: 'Alice');
    expect(find.text('Alice'), findsOneWidget);
    // No empty-state text when photos exist.
    expect(find.text('No photos yet'), findsNothing);
  });

  testWidgets('shows the empty state when the member has no new photos', (tester) async {
    final fs = FakeFirebaseFirestore();
    await pumpStory(tester, fs, uploaderUid: 'bob', name: 'Bob');
    expect(find.text('No new photos'), findsOneWidget);
  });

  testWidgets('view-once: an already-seen photo is not shown again', (tester) async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('squads/s1/photos/a1').set(photo('alice', 1));
    // Pre-mark a1 seen via the provider's prefs key for uid "me".
    SharedPreferences.setMockInitialValues({'proof.seen.me': ['a1']});
    await pumpStory(tester, fs, uploaderUid: 'alice', name: 'Alice');
    expect(find.text('No new photos'), findsOneWidget); // a1 filtered out
  });
}
