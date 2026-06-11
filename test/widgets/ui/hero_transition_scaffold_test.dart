import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/hero_transition_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('HeroTransitionScaffold renders and its route pushes a page',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: HeroTransitionScaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                HeroTransitionScaffold.route(
                  const HeroTransitionScaffold(body: Text('Detail')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));

    expect(find.byType(HeroTransitionScaffold), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  });
}
