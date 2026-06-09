import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'squad_service.dart';

/// Lets foreground FCM messages surface an in-app SnackBar (set as
/// MaterialApp.scaffoldMessengerKey).
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Background/terminated handler. The system auto-displays FCM *notification*
/// messages, so this is a no-op hook (must be a top-level entry point).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// FCM setup + token management for Squad push notifications.
class NotificationService {
  final FirebaseMessaging _fm;
  final SquadService _squad;
  String? _token;

  NotificationService({FirebaseMessaging? messaging, SquadService? squad})
      : _fm = messaging ?? FirebaseMessaging.instance,
        _squad = squad ?? SquadService();

  /// Requests permission and wires the foreground listener. Call once at start.
  Future<void> init() async {
    try {
      await _fm.requestPermission();
      FirebaseMessaging.onMessage.listen(_onForeground);
    } catch (_) {/* messaging unavailable — local app unaffected */}
  }

  void _onForeground(RemoteMessage message) {
    final n = message.notification;
    final text = n?.body ?? n?.title;
    if (text != null) {
      rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  /// Saves this device's FCM token to the user, keeps it fresh, and records the
  /// timezone offset (for the scheduled end-of-day summary).
  Future<void> registerForUser(String uid) async {
    try {
      _token = await _fm.getToken();
      if (_token != null) await _squad.addFcmToken(uid, _token!);
      _fm.onTokenRefresh.listen((t) {
        _token = t;
        _squad.addFcmToken(uid, t);
      });
      await _squad.setTimezoneOffset(uid, DateTime.now().timeZoneOffset.inMinutes);
    } catch (_) {/* best-effort */}
  }

  Future<void> unregisterForUser(String uid) async {
    try {
      if (_token != null) await _squad.removeFcmToken(uid, _token!);
    } catch (_) {/* best-effort */}
  }
}

/// Shared instance (used by main for init and AuthProvider for token mgmt).
final notificationService = NotificationService();
