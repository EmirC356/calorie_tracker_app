import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/photo.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';

/// Holds the proof photos for the squad currently being viewed. Auth-aware like
/// the other squad providers: detaches + clears on sign-out, re-attaches on
/// sign-in. Supports optimistic inserts so a freshly-shot photo renders before
/// the Storage/Firestore round-trip confirms.
class PhotoProvider extends ChangeNotifier {
  final PhotoService _service;
  AuthService? _authService;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<Photo>>? _sub;
  String? _squadId;
  String? _uid;
  bool _signedIn = false;
  List<Photo> _photos = const [];
  final List<Photo> _optimistic = [];

  // View-once: photoIds the signed-in user has already viewed (local, per-account).
  final Set<String> _seen = {};

  PhotoService get service => _service;
  String? get uid => _uid;

  PhotoProvider({PhotoService? service, AuthService? authService})
      : _service = service ?? PhotoService() {
    try {
      _authService = authService ?? AuthService();
      final cur = _authService!.currentUser;
      _signedIn = cur != null;
      _uid = cur?.uid;
      if (_signedIn) _loadSeen();
      _authSub = _authService!.authStateChanges().listen((u) {
        _signedIn = u != null;
        _uid = u?.uid;
        if (!_signedIn) {
          _detach();
        } else {
          _loadSeen();
          if (_squadId != null && _sub == null) _attach(_squadId!);
        }
      });
    } catch (e) {
      debugPrint('PhotoProvider: auth unavailable: $e');
    }
  }

  String get _seenKey => 'proof.seen.${_uid ?? 'anon'}';

  Future<void> _loadSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen
        ..clear()
        ..addAll(prefs.getStringList(_seenKey) ?? const []);
      notifyListeners();
    } catch (_) {/* best-effort */}
  }

  /// Whether the current user has already viewed [photoId] (Snapchat view-once).
  bool isSeen(String photoId) => _seen.contains(photoId);

  /// Mark a photo viewed so it won't be shown again. Capped at the last 1000.
  Future<void> markSeen(String photoId) async {
    if (!_seen.add(photoId)) return;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      var list = _seen.toList();
      if (list.length > 1000) list = list.sublist(list.length - 1000);
      await prefs.setStringList(_seenKey, list);
    } catch (_) {}
  }

  DateTime _ts(Photo p) =>
      p.uploadedAt ?? DateTime.now(); // optimistic/pending float to the top

  /// Visible photos (published + my own pending + optimistic), newest first.
  List<Photo> get recentPhotos {
    final byId = <String, Photo>{for (final p in _photos) p.id: p};
    for (final o in _optimistic) {
      byId.putIfAbsent(o.id, () => o);
    }
    return byId.values.where((p) => p.visibleTo(_uid)).toList()
      ..sort((a, b) => _ts(b).compareTo(_ts(a)));
  }

  /// My own not-yet-published photos (still inside the undo window).
  List<Photo> get pendingMyPhotos =>
      recentPhotos.where((p) => p.isPending && p.uploadedByUid == _uid).toList();

  /// Published, visible photos (the Gallery surface paginates over these).
  List<Photo> get gallery =>
      recentPhotos.where((p) => p.published).toList();

  void bind(String squadId) {
    if (squadId == _squadId && _sub != null) return;
    _squadId = squadId;
    _photos = const [];
    _optimistic.clear();
    if (_signedIn) _attach(squadId);
    notifyListeners();
  }

  void _attach(String squadId) {
    _sub?.cancel();
    _sub = _service.streamForSquad(squadId).listen(
      (list) {
        _photos = list;
        // Reconcile: drop any optimistic placeholder now confirmed by Firestore.
        _optimistic.removeWhere((o) => list.any((p) => p.id == o.id));
        notifyListeners();
      },
      onError: (_) {/* feed is best-effort */},
    );
  }

  void _detach() {
    _sub?.cancel();
    _sub = null;
    _photos = const [];
    _optimistic.clear();
    notifyListeners();
  }

  /// Insert a local placeholder before the upload confirms (snappy strip).
  void addOptimisticPhoto(Photo p) {
    _optimistic.insert(0, p);
    notifyListeners();
  }

  /// Drop a placeholder whose upload failed.
  void removeOptimisticPhoto(String id) {
    _optimistic.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
