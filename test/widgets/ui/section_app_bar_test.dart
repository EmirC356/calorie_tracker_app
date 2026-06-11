import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/section_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('SectionAppBar renders title, caption and actions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        appBar: SectionAppBar(
          title: 'Health',
          caption: 'Wednesday, Jun 11',
          accent: AppColors.healthRed,
          actions: const [Icon(Icons.settings)],
        ),
        body: const SizedBox(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SectionAppBar), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('WEDNESDAY, JUN 11'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
