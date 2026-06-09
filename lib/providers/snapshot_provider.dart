import 'dart:async';
import 'package:flutter/widgets.dart';
import '../services/snapshot_service.dart';
import 'auth_provider.dart';

/// Coordinates daily-snapshot uploads. Triggers (per spec):
///  - app foreground (resumed)
///  - after any local meal/exercise/weight change (the bound ChangeNotifiers)
///  - a 5-minute periodic timer while the app runs
///  - day rollover (finalizes the previous day once)
///
/// All work is best-effort and guarded — a cloud failure never affects local
/// features. Pushes only happen while signed in.
class SnapshotProvider extends ChangeNotifier with WidgetsBindingObserver {
  final SnapshotService _service;

  String? _uid;
  Timer? _debounce;
  Timer? _periodic;
  String? _lastDateKey;
  bool _attached = false;
  final List<ChangeNotifier> _sources = [];
  AuthProvider? _auth;

  SnapshotProvider({SnapshotService? service}) : _service = service ?? SnapshotService();

  /// Wire up the auth source (for uid) and the local-data sources (meal/
  /// exercise/weight providers). Safe to call once.
  void attach({required AuthProvider auth, required List<ChangeNotifier> localSources}) {
    if (_attached) return;
    _attached = true;
    _auth = auth;
    auth.addListener(_onAuthChanged);
    _sources.addAll(localSources);
    for (final s in localSources) {
      s.addListener(_onLocalChange);
    }
    WidgetsBinding.instance.addObserver(this);
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => pushNow());
    _onAuthChanged(); // pick up an already-signed-in user
  }

  void _onAuthChanged() {
    final uid = _auth?.firebaseUser?.uid;
    if (uid == _uid) return;
    _uid = uid;
    if (uid != null) pushNow();
  }

  void _onLocalChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), pushNow);
  }

  /// Force a push now (also called by the Today tab on open).
  Future<void> pushNow() async {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now();
    final todayKey = SnapshotService.dateKey(now);
    // Day rollover: finalize yesterday one last time (locks in 'missed').
    if (_lastDateKey != null && _lastDateKey != todayKey) {
      final yesterday = now.subtract(const Duration(days: 1));
      try {
        await _service.pushForUser(uid: uid, date: yesterday, now: now);
      } catch (_) {/* best-effort */}
    }
    _lastDateKey = todayKey;
    try {
      await _service.pushForUser(uid: uid, date: now, now: now);
    } catch (_) {/* best-effort */}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) pushNow();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    _auth?.removeListener(_onAuthChanged);
    for (final s in _sources) {
      s.removeListener(_onLocalChange);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
