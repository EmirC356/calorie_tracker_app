import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/services/auth_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/providers/squad_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Let the fake-Firestore + auth streams propagate.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

  test('squads reload after sign-out → same-account sign-in (no permission error)', () async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('squads/s1').set({
      'name': 'Gym', 'ownerUid': 'u1', 'memberUids': ['u1'],
      'inviteCode': '123456', 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    final service = SquadService(firestore: fs);
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1', displayName: 'A'));
    final authService = AuthService(auth: mockAuth, googleSignIn: GoogleSignIn());

    final provider = SquadProvider(service: service, authService: authService);
    await settle();

    // Initial signed-in load.
    expect(provider.currentUid, 'u1');
    expect(provider.squads.map((s) => s.id), contains('s1'));
    expect(provider.error, isNull);
    expect(provider.connected, isTrue);

    // Sign out → stream torn down, state cleared.
    await mockAuth.signOut();
    await settle();
    expect(provider.currentUid, isNull);
    expect(provider.squads, isEmpty);
    expect(provider.lastKnownUid, 'u1'); // retained for diagnostics

    // Sign back in with the SAME account → the old bug left a dead listener and
    // surfaced permission-denied; now it must re-attach and reload cleanly.
    await mockAuth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: 'id', accessToken: 'acc'));
    await settle();
    expect(provider.currentUid, 'u1');
    expect(provider.squads.map((s) => s.id), contains('s1'));
    expect(provider.error, isNull);

    provider.dispose();
  });

  test('a null auth user clears squad state without attaching a listener', () async {
    final fs = FakeFirebaseFirestore();
    final service = SquadService(firestore: fs);
    final mockAuth = MockFirebaseAuth(signedIn: false);
    final provider = SquadProvider(service: service, authService: AuthService(auth: mockAuth, googleSignIn: GoogleSignIn()));
    await settle();

    expect(provider.currentUid, isNull);
    expect(provider.squads, isEmpty);
    expect(provider.error, isNull);

    provider.dispose();
  });
}
