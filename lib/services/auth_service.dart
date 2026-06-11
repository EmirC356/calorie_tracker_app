import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Firebase Auth + Google Sign-In. The only auth method is Google.
/// Dependencies are injectable so tests can pass mocks (no live Firebase).
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  /// Mirrors [FirebaseAuth.authStateChanges]. Emits the current user on listen,
  /// then on every sign-in / sign-out. Auth-listening providers drive their
  /// Firestore subscriptions off this so a re-login re-attaches cleanly.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Returns the credential on success, or null if the user cancelled the
  /// Google chooser. Throws [FirebaseAuthException] on auth failures.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    // Force-refresh the ID token so the first Firestore query right after
    // sign-in carries a fresh token — otherwise a query can race a still-
    // rehydrating token and get rejected with permission-denied.
    await cred.user?.getIdToken(true);
    return cred;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
