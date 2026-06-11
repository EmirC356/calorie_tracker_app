import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/hero_stat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('HeroStat renders value, target and label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(
        body: HeroStat(value: 1840, target: 2200, label: 'Calories today'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(HeroStat), findsOneWidget);
    expect(find.text('CALORIES TODAY'), findsOneWidget);
    expect(find.text('1840'), findsOneWidget);
    expect(find.text('/ 2200'), findsOneWidget);
  });
}
