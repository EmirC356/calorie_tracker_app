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
import 'package:calorie_tracker_app/screens/health/personal_proof_gallery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, FakeFirebaseFirestore fs) async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me'));
    final service = PhotoService(firestore: fs, auth: auth, put: (a, b, c, d) async {},
        resolveUrl: (p) async => 'https://example.test/$p');
    final authService = AuthService(auth: auth, googleSignIn: GoogleSignIn());
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PhotoProvider(service: service, authService: authService))],
      child: const MaterialApp(home: PersonalProofGalleryScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('renders the grid + month filter when proofs exist', (tester) async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('users/me/personalProof/p1').set({
      'ownerUid': 'me', 'storagePath': 'x', 'deletedAt': null,
      'uploadedAt': Timestamp.fromDate(DateTime(2026, 6, 12)),
      'goalRef': {'goalId': 'g', 'occurrenceDate': '2026-06-12', 'title': 'Read'},
    });
    await fs.doc('users/me/personalProof/p2').set({
      'ownerUid': 'me', 'storagePath': 'y', 'deletedAt': null,
      'uploadedAt': Timestamp.fromDate(DateTime(2026, 5, 3)),
      'goalRef': {'goalId': 'g', 'occurrenceDate': '2026-05-03', 'title': 'Run'},
    });
    await pump(tester, fs);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Jun 2026'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no proofs', (tester) async {
    await pump(tester, FakeFirebaseFirestore());
    expect(find.text('No personal proof yet'), findsOneWidget);
  });
}
