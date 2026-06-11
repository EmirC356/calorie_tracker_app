import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/animated_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('AnimatedRing renders and settles with a center child',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(
        body: AnimatedRing(
          progress: 0.7,
          accent: AppColors.squadBlue,
          child: Text('70%'),
        ),
      ),
    ));
    // Let the spring simulation settle.
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(AnimatedRing), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
  });
}
