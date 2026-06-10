import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/squad.dart';
import '../models/squad_reaction.dart';
import '../services/squad_service.dart';

const String _kNudgePref = 'squad_nudge_cooldowns';

/// Streams the signed-in user's squads and exposes create/join actions.
/// Call [bind] with the current uid (and null on sign-out).
class SquadProvider extends ChangeNotifier {
  final SquadService _service;
  String? _uid;
  StreamSubscription<List<Squad>>? _sub;

  List<Squad> _squads = [];
  bool _loading = false;
  String? _error;
  String _displayName = 'Athlete';
  String? _photoURL;

  SquadProvider({SquadService? service}) : _service = service ?? SquadService() {
    _loadNudges();
  }

  List<Squad> get squads => _squads;
  bool get loading => _loading;
  String? get error => _error;
  SquadService get service => _service;

  void bind(String? uid, {String displayName = 'Athlete', String? photoURL}) {
    _displayName = displayName;
    _photoURL = photoURL;
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    if (uid == null) {
      _squads = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    _sub = _service.watchMySquads(uid).listen(
      (list) {
        _squads = list;
        _loading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
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
    _sub?.cancel();
    super.dispose();
  }
}
