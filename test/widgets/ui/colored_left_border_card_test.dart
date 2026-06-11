import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/colored_left_border_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('ColoredLeftBorderCard renders child and handles tap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: ColoredLeftBorderCard(
          accent: AppColors.calendarAmber,
          onTap: () => tapped = true,
          child: const Text('Morning run'),
        ),
      ),
    ));

    expect(find.text('Morning run'), findsOneWidget);
    await tester.tap(find.byType(ColoredLeftBorderCard));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
