import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/shimmer_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('ShimmerPlaceholder variants render', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(
        body: Column(
          children: [
            ShimmerPlaceholder.card(),
            ShimmerPlaceholder.line(),
            ShimmerPlaceholder(width: 80, height: 80, radius: 999),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ShimmerPlaceholder), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
