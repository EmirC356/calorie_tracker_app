import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/providers/photo_provider.dart';
import 'package:calorie_tracker_app/services/auth_service.dart';
import 'package:calorie_tracker_app/services/photo_service.dart';
import 'package:calorie_tracker_app/widgets/squad/photo_strip.dart';
import 'package:calorie_tracker_app/widgets/squad/photo_thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PhotoService svc(FakeFirebaseFirestore fs) => PhotoService(
        firestore: fs,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
        put: (a, b, c, d) async {},
        resolveUrl: (p) async => 'https://example.test/$p',
      );

  Future<void> pumpFab(WidgetTester tester, FakeFirebaseFirestore fs, int count) async {
    await fs.doc('squads/s1').set({'name': 'S', 'ownerUid': 'me', 'memberUids': ['me'], 'inviteCode': '123456'});
    for (var i = 0; i < count; i++) {
      await fs.doc('squads/s1/photos/p$i').set({
        'uploadedByUid': 'other', 'uploadedByName': 'O', 'published': true,
        'publishedAt': Timestamp.fromDate(DateTime(2026, 6, 12, 12, i)),
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 6, 12, 12, i)),
        'deletedAt': null, 'storagePath': 'squads/s1/photos/p$i.jpg',
        'reactionCounts': {'fire': 0, 'flex': 0, 'clap': 0},
      });
    }
    final service = svc(fs);
    final authService = AuthService(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
        googleSignIn: GoogleSignIn());
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PhotoProvider(service: service, authService: authService))],
      child: const MaterialApp(home: Scaffold(floatingActionButton: CameraFab(squadId: 's1'))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('CameraFab with no photos → camera button only, no preview', (tester) async {
    await pumpFab(tester, FakeFirebaseFirestore(), 0);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(PhotoThumbnail), findsNothing);
  });

  testWidgets('CameraFab with photos → shows the latest-photo preview badge', (tester) async {
    await pumpFab(tester, FakeFirebaseFirestore(), 3);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(PhotoThumbnail), findsOneWidget); // a single preview, not a strip
  });
}
