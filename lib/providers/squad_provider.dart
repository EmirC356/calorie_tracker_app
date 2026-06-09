import 'dart:async';
import 'package:flutter/material.dart';
import '../models/squad.dart';
import '../services/squad_service.dart';

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

  SquadProvider({SquadService? service}) : _service = service ?? SquadService();

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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
