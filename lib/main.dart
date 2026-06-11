import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'services/notification_service.dart';
import 'providers/meal_provider.dart';
import 'providers/exercise_provider.dart';
import 'providers/meal_prep_provider.dart';
import 'providers/weight_provider.dart';
import 'providers/water_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/squad_provider.dart';
import 'providers/snapshot_provider.dart';
import 'providers/goal_provider.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'services/streak_warning_service.dart';
import 'services/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';

// Optional one-time key seed: launch with
//   flutter run --dart-define=GEMINI_KEY=your_key
// to write the key into the device's local storage. It then persists across
// restarts, so the define is only needed once. Nothing is stored in source.
const _seedKey = String.fromEnvironment('GEMINI_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase powers the cloud-synced Squad feature only. initializeApp() reads
  // local config (no network), so it never blocks the offline-first app. Guard
  // it so a config problem can't take down the local meal/exercise/weight UI;
  // the Squad providers are created lazily and surface errors only there.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await notificationService.init();
    // Route uncaught Flutter + platform errors to Crashlytics (so we hear about
    // crashes on testers' devices). Guarded with the rest of Firebase init.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Firebase init failed (Squad features disabled): $e');
  }
  if (_seedKey.isNotEmpty) {
    await aiService.initialize(_seedKey); // seed + persist
  } else {
    await aiService.loadFromStorage(); // restore on cold start
  }
  // (Re)schedule the daily squad streak warning from the saved preference.
  try {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(kStreakWarnHourPref) ?? 21;
    await StreakWarningService.schedule(
        hour: hour, body: "Don't lose your streak — log today to keep it alive.");
  } catch (e) {
    debugPrint('Streak warning scheduling skipped: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MealProvider()),
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => MealPrepProvider()),
        ChangeNotifierProvider(create: (_) => WeightProvider()),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        // BYO AI: the single shared instance, so the lock overlay reacts to key
        // changes app-wide.
        ChangeNotifierProvider<AiService>.value(value: aiService),
        // Calendar/Goals — local-only, loads lazily on first Calendar open.
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        // AuthProvider stays lazy (its ctor touches FirebaseAuth; HomeScreen
        // reads it at startup inside a guard, so it still hears auth early).
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Eager: these subscribe to auth state in their constructors, so they
        // must exist from launch to catch a sign-in that happens before the
        // Squad tab is ever opened. Both ctors are guarded against a missing
        // Firebase init, so eagerness can't take down the local-only tabs.
        ChangeNotifierProvider(create: (_) => SquadProvider(), lazy: false),
        ChangeNotifierProvider(create: (_) => SnapshotProvider(), lazy: false),
      ],
      child: MaterialApp(
        title: 'Calorie Tracker',
        theme: buildAppTheme(),
        scaffoldMessengerKey: rootMessengerKey, // foreground push -> in-app banner
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
