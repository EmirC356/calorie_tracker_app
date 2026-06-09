import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/index.dart';
import '../services/prefs.dart';

/// Holds the persisted [UserProfile] and exposes it to the widget tree.
class ProfileProvider extends ChangeNotifier {
  UserProfile? _profile;

  UserProfile? get profile => _profile;
  bool get hasProfile => _profile?.isComplete ?? false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kUserProfilePref);
    if (raw != null && raw.isNotEmpty) {
      _profile = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    notifyListeners();
  }

  Future<void> save(UserProfile profile) async {
    _profile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserProfilePref, jsonEncode(profile.toJson()));
    notifyListeners();
  }
}
