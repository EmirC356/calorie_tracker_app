import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/index.dart';
import '../services/auth_service.dart';
import '../services/squad_service.dart';

/// A single activity-feed listener for the squad currently being viewed.
/// Auth-aware like [SquadProvider]: detaches + clears on sign-out, re-attaches
/// on sign-in. Call [bind] with the open squad's id (re-binding swaps listeners).
class ActivityFeedProvider extends ChangeNotifier {
  final SquadService _service;
  AuthService? _authService;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<SquadActivity>>? _sub;
  String? _squadId;
  bool _signedIn = false;
  List<SquadActivity> _events = const [];

  ActivityFeedProvider({SquadService? service, AuthService? authService})
      : _service = service ?? SquadService() {
    try {
      _authService = authService ?? AuthService();
      _signedIn = _authService!.currentUser != null;
      _authSub = _authService!.authStateChanges().listen((u) {
        _signedIn = u != null;
        if (!_signedIn) {
          _detach();
        } else if (_squadId != null && _sub == null) {
          _attach(_squadId!);
        }
      });
    } catch (e) {
      debugPrint('ActivityFeedProvider: auth unavailable: $e');
    }
  }

  List<SquadActivity> get events => _events;

  /// Bind to the squad being viewed; swaps the live listener.
  void bind(String squadId) {
    if (squadId == _squadId && _sub != null) return;
    _squadId = squadId;
    _events = const [];
    if (_signedIn) _attach(squadId);
  }

  void _attach(String squadId) {
    _sub?.cancel();
    _sub = _service.watchActivity(squadId, limit: 30).listen(
      (list) {
        _events = list;
        notifyListeners();
      },
      onError: (_) {/* feed is best-effort */},
    );
  }

  void _detach() {
    _sub?.cancel();
    _sub = null;
    _events = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
