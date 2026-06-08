import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/meal_provider.dart';
import 'providers/exercise_provider.dart';
import 'providers/meal_prep_provider.dart';
import 'providers/weight_provider.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'theme/app_theme.dart';

// Optional one-time key seed: launch with
//   flutter run --dart-define=GEMINI_KEY=your_key
// to write the key into the device's local storage. It then persists across
// restarts, so the define is only needed once. Nothing is stored in source.
const _seedKey = String.fromEnvironment('GEMINI_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_seedKey.isNotEmpty) {
    await aiService.initialize(_seedKey); // seed + persist
  } else {
    await aiService.loadFromStorage(); // restore on cold start
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
      ],
      child: MaterialApp(
        title: 'Calorie Tracker',
        theme: buildCyberpunkTheme(),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
