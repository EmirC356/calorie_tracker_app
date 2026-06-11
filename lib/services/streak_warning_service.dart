import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the daily local "streak at-risk" warning. The precise per-squad
/// body is computed by the app while active (any squad still inProgress today +
/// streak ≥ 3) and passed to [schedule]; a true fire-time recheck would need a
/// background task (out of scope), so the body reflects the latest app-active
/// state and is cancelled the moment the user is no longer at risk.
class StreakWarningService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;
  static const int _id = 9001;

  static Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _inited = true;
  }

  /// Body for the at-risk squads — collapsed into ONE message (max 3 named), so
  /// a multi-squad evening is still a single push. Null when nothing's at risk.
  static String? buildBody(List<({String squad, int streak})> atRisk) {
    if (atRisk.isEmpty) return null;
    if (atRisk.length == 1) {
      final a = atRisk.first;
      return 'Your ${a.streak}-day streak in ${a.squad} ends in ~3 hours. Log to keep it alive.';
    }
    final names = atRisk.take(3).map((a) => a.squad).join(', ');
    return '${atRisk.length} streaks at risk ($names). Log today to keep them alive.';
  }

  /// Schedules the daily warning at [hour]:00 local (hour < 0 = off / no risk).
  /// [quietStartHour]/[quietEndHour] suppress it if [hour] is inside quiet hours.
  static Future<void> schedule({
    required int hour,
    required String body,
    int quietStartHour = 23,
    int quietEndHour = 7,
  }) async {
    await init();
    await _plugin.cancel(_id);
    if (hour < 0) return;
    if (_inQuietHours(hour, quietStartHour, quietEndHour)) return; // dropped, not queued

    await _plugin.zonedSchedule(
      _id,
      'Streak at risk 🔥',
      body,
      _nextInstant(hour),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_warn', 'Streak warnings',
          channelDescription: 'Evening reminder when a squad streak is about to break',
          importance: Importance.high, priority: Priority.high),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  static Future<void> cancel() async {
    await init();
    await _plugin.cancel(_id);
  }

  static bool _inQuietHours(int hour, int start, int end) =>
      start <= end ? (hour >= start && hour < end) : (hour >= start || hour < end);

  /// The next [hour]:00 in device-local wall time, as a UTC instant (tz.local
  /// defaults to UTC; the daily match then repeats at the same wall clock).
  static tz.TZDateTime _nextInstant(int hour) {
    final now = DateTime.now();
    var local = DateTime(now.year, now.month, now.day, hour);
    if (!local.isAfter(now)) local = local.add(const Duration(days: 1));
    return tz.TZDateTime.from(local.toUtc(), tz.UTC);
  }
}
