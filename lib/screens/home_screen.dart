import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/weight_provider.dart';
import '../providers/water_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/snapshot_provider.dart';
import '../providers/goal_provider.dart';
import 'squad/squad_tab.dart';
import 'health/health_shell_screen.dart';
import 'calendar/calendar_screen.dart';

/// Top-level bottom-nav host. Three tabs: **Squads · Health · Calendar**.
/// The Squad tab is the cloud/social area, Health collapses the old local-only
/// tabs (Dashboard/Meals/Fitness/Weight/Advisor) behind a sub-TabBar, and
/// Calendar is the new Goals surface.
///
/// The body is rebuilt per selection (rather than an IndexedStack) so the Squad
/// tab — and the lazily-created AuthProvider it watches — is only constructed
/// when the user opens it, keeping a Firebase issue away from the local tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Default to the Health tab so the app opens on useful local content (its
  // Dashboard sub-tab) — same landing as before the nav collapse — instead of
  // a sign-in prompt.
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    // Capture providers synchronously, then load after the first frame so we
    // don't notifyListeners() mid-build.
    final meals = context.read<MealProvider>();
    final exercises = context.read<ExerciseProvider>();
    final profile = context.read<ProfileProvider>();
    final weight = context.read<WeightProvider>();
    final water = context.read<WaterProvider>();
    final goals = context.read<GoalProvider>();
    Future.microtask(() {
      meals.loadTodaysMeals();
      meals.loadMeals(); // full history for the 14-day calories chart
      exercises.loadTodaysExercises();
      profile.load();
      weight.loadEntries();
      water.loadToday();
    });
    // Wire the cloud snapshot aggregator to local data + auth. Goals are a
    // source too, so toggling a goal squad-visible (or archiving it) syncs the
    // cloud goalsVisible docs promptly. Guarded so a Firebase-less environment
    // can't break the local-only app.
    try {
      context.read<SnapshotProvider>().attach(
            auth: context.read<AuthProvider>(),
            localSources: [meals, exercises, weight, goals],
          );
    } catch (e) {
      debugPrint('Snapshot aggregator not attached: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Squads'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Health'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
        ],
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return const SquadTab();
      case 1: return const HealthShellScreen();
      case 2: return const CalendarScreen();
      default: return const HealthShellScreen();
    }
  }
}
