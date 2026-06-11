import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/squad.dart';
import '../models/squad_reaction.dart';
import '../services/auth_service.dart';
import '../services/squad_service.dart';

const String _kNudgePref = 'squad_nudge_cooldowns';

/// Streams the signed-in user's squads and exposes create/join actions.
///
/// The Firestore stream is driven by **auth state**, not the screen: the
/// provider subscribes to [AuthService.authStateChanges] and (re)attaches a
/// fresh listener on every sign-in, tearing it down + clearing state on
/// sign-out. This fixes the post-relogin permission-denied bug — a same-account
/// sign-out → sign-in re-attaches with a fresh token instead of leaving the
/// dead listener (the old screen-driven `bind` short-circuited on equal uid).
class SquadProvider extends ChangeNotifier {
  final SquadService _service;
  AuthService? _authService;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<Squad>>? _sub;

  String? _uid;
  String? _lastKnownUid; // survives sign-out — for the Diagnostics screen
  List<Squad> _squads = [];
  bool _loading = false;
  String? _error;
  bool _connected = false;
  String _displayName = 'Athlete';
  String? _photoURL;

  SquadProvider({SquadService? service, AuthService? authService})
      : _service = service ?? SquadService() {
    _loadNudges();
    try {
      _authService = authService ?? AuthService();
      _authSub = _authService!.authStateChanges().listen(_onAuth);
      final current = _authService!.currentUser;
      if (current != null) _attach(current.uid);
    } catch (e) {
      // Firebase unavailable (e.g. init failed) — stay inert so the local-only
      // tabs are unaffected. The Squad tab surfaces the error via [error].
      debugPrint('SquadProvider: auth stream unavailable: $e');
    }
  }

  List<Squad> get squads => _squads;
  bool get loading => _loading;
  String? get error => _error;
  SquadService get service => _service;

  // Diagnostics (surfaced by the hidden Settings → Diagnostics screen).
  String? get currentUid => _uid;
  String? get lastKnownUid => _lastKnownUid;
  bool get connected => _connected;

  void _onAuth(User? user) {
    if (user == null) {
      _detach();
      return;
    }
    // authStateChanges emits null on sign-out before the new user, so even a
    // same-account re-login lands here with _uid already reset → re-attach.
    if (user.uid != _uid || _sub == null) _attach(user.uid);
  }

  void _attach(String uid) {
    _sub?.cancel();
    _uid = uid;
    _lastKnownUid = uid;
    _loading = true;
    _error = null;
    _connected = false;
    notifyListeners();
    _sub = _service.watchMySquads(uid).listen(
      (list) {
        _squads = list;
        _loading = false;
        _connected = true;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        _connected = false;
        notifyListeners();
      },
    );
  }

  void _detach() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _squads = [];
    _loading = false;
    _error = null;
    _connected = false;
    notifyListeners();
  }

  /// Updates the denormalized identity (display name / photo) used when creating
  /// or joining squads. The Firestore stream itself is auth-driven (above); this
  /// also re-attaches if a stream isn't live or is in an error state while
  /// signed in — so pull-to-refresh recovers a transient permission error.
  void bind(String? uid, {String displayName = 'Athlete', String? photoURL}) {
    _displayName = displayName;
    _photoURL = photoURL;
    if (uid == null) {
      if (_uid != null) _detach();
      return;
    }
    if (_sub == null || _uid != uid || _error != null) _attach(uid);
  }

  Future<Squad> createSquad(String name) {
    if (_uid == null) throw const SquadException('Not signed in.');
    return _service.createSquad(
        name: name, ownerUid: _uid!, displayName: _displayName, photoURL: _photoURL);
  }

  Future<Squad> joinSquad(String code) {
    if (_uid == null) throw const SquadException('Not signed in.');
    return _service.joinSquadByCode(
        code: code, uid: _uid!, displayName: _displayName, photoURL: _photoURL);
  }

  // ── nudge cooldown (device-clock, skew-free) ────────────────────────────────
  // Tracked locally with DateTime.now() on both ends so it can't get stuck the
  // way a server-timestamp-vs-device-clock comparison can.
  final Map<String, DateTime> _lastNudgeAt = {};

  Duration nudgeCooldownRemaining(String squadId, String toUid,
      [Duration cooldown = kReactionCooldown]) {
    final last = _lastNudgeAt['$squadId:$toUid'];
    if (last == null) return Duration.zero;
    final remaining = cooldown - DateTime.now().difference(last);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void markNudged(String squadId, String toUid) {
    _lastNudgeAt['$squadId:$toUid'] = DateTime.now();
    _saveNudges();
  }

  /// Loads persisted nudge timestamps, dropping any already past the cooldown.
  Future<void> _loadNudges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNudgePref);
      if (raw == null) return;
      final now = DateTime.now();
      (jsonDecode(raw) as Map).forEach((k, v) {
        final t = DateTime.tryParse(v as String);
        if (t != null && now.difference(t) < kReactionCooldown) {
          _lastNudgeAt[k as String] = t;
        }
      });
    } catch (_) {/* best-effort */}
  }

  Future<void> _saveNudges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNudgePref,
          jsonEncode(_lastNudgeAt.map((k, v) => MapEntry(k, v.toIso8601String()))));
    } catch (_) {/* best-effort */}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
