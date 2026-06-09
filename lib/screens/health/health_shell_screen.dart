import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../weight_tracker_screen.dart';
import '../meal_advice_screen.dart';
import 'dashboard_screen.dart';
import 'meals_tab_screen.dart';
import 'fitness_tab_screen.dart';

/// The Health tab. Collapses everything that used to live on the Home / Meals /
/// Fitness / Weight / Advisor bottom-nav tabs into a single tab with a top
/// sub-TabBar. Each sub-tab keeps its own AppBar (so the Dashboard gear still
/// opens Settings, "same as today") under a slim section switcher.
class HealthShellScreen extends StatelessWidget {
  const HealthShellScreen({super.key});

  static const _tabs = <Tab>[
    Tab(text: 'Dashboard'),
    Tab(text: 'Meals'),
    Tab(text: 'Fitness'),
    Tab(text: 'Weight'),
    Tab(text: 'Advisor'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            Material(
              color: kSurface,
              child: const TabBar(
                isScrollable: true,
                indicatorColor: kRed,
                labelColor: kRed,
                unselectedLabelColor: kTextDim,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: _tabs,
              ),
            ),
            const Expanded(
              child: TabBarView(children: [
                DashboardScreen(),
                MealsTabScreen(),
                FitnessTabScreen(),
                WeightTrackerScreen(),
                MealAdviceScreen(),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
