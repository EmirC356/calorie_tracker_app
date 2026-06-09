import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/squad_service.dart';

/// Exposes auth state + the cloud [AppUser] to the widget tree. Created lazily
/// (only when the Squad tab is first opened).
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final SquadService _squadService;
  StreamSubscription<User?>? _sub;

  User? _firebaseUser;
  AppUser? _appUser;
  bool _busy = false;
  bool _needsProfileSetup = false;
  String? _error;

  AuthProvider({AuthService? authService, SquadService? squadService})
      : _authService = authService ?? AuthService(),
        _squadService = squadService ?? SquadService() {
    _firebaseUser = _authService.currentUser;
    _sub = _authService.authStateChanges().listen(_onAuthChanged);
    if (_firebaseUser != null) {
      _syncUserDoc(_firebaseUser!);
    }
  }

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isSignedIn => _firebaseUser != null;
  bool get isBusy => _busy;
  bool get needsProfileSetup => _needsProfileSetup;
  String? get error => _error;

  Future<void> _onAuthChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      await _syncUserDoc(user);
    } else {
      _appUser = null;
    }
    notifyListeners();
  }

  Future<void> _syncUserDoc(User user) async {
    try {
      _appUser = await _squadService.ensureUserDocument(user);
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Starts the Google sign-in flow. Returns null on success/cancel, or an
  /// error string on failure. Sets [needsProfileSetup] for first-time users.
  Future<String?> signIn() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred == null) return null; // cancelled
      if (cred.additionalUserInfo?.isNewUser ?? false) {
        _needsProfileSetup = true;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      return _error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _needsProfileSetup = false;
  }

  Future<void> saveProfile(String displayName) async {
    final uid = _firebaseUser?.uid;
    if (uid == null) return;
    final name = displayName.trim().isEmpty ? 'Athlete' : displayName.trim();
    await _squadService.updateDisplayName(uid, name);
    _appUser = _appUser?.copyWith(displayName: name);
    _needsProfileSetup = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
