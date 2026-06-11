import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/animated_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('AnimatedNumber tickers to the target value', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: AnimatedNumber(value: 72.5, style: AppText.titleM, decimals: 1, suffix: ' kg'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(AnimatedNumber), findsOneWidget);
    expect(find.text('72.5 kg'), findsOneWidget);
  });
}
