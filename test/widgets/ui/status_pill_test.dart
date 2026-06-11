import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('StatusPill renders all variants', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(
        body: Column(
          children: [
            StatusPill(status: PillStatus.hit),
            StatusPill(status: PillStatus.inProgress),
            StatusPill(status: PillStatus.missed),
            StatusPill(status: PillStatus.paused, label: 'On break'),
          ],
        ),
      ),
    ));

    expect(find.byType(StatusPill), findsNWidgets(4));
    expect(find.text('Hit'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('On break'), findsOneWidget);
  });
}
