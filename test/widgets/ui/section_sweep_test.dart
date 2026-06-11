import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/section_sweep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('SectionSweep overlays, animates, and self-removes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                SectionSweep.show(context, AppColors.squadBlue),
            child: const Text('Sweep'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Sweep'));
    await tester.pump();
    expect(find.byType(IgnorePointer), findsWidgets);

    // Past sweepDuration the overlay entry removes itself.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
