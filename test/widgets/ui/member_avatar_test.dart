import 'package:calorie_tracker_app/theme/app_theme.dart';
import 'package:calorie_tracker_app/widgets/ui/member_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget wrap(Widget child) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('plain avatar (0 streak) shows initials, no flame',
      (tester) async {
    await tester
        .pumpWidget(wrap(const MemberAvatar(displayName: 'Emir Ceylan')));
    expect(find.text('EC'), findsOneWidget);
    expect(find.text('🔥'), findsNothing);
  });

  testWidgets('mid streak shows flame badge', (tester) async {
    await tester.pumpWidget(wrap(
        const MemberAvatar(displayName: 'Emir', currentStreak: 5)));
    expect(find.text('🔥'), findsOneWidget);
  });

  testWidgets('pulsing tier (20 streak) renders without exception',
      (tester) async {
    await tester.pumpWidget(wrap(
        const MemberAvatar(displayName: 'Emir', currentStreak: 20)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('🔥'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused shows palm chip instead of flame', (tester) async {
    await tester.pumpWidget(wrap(const MemberAvatar(
        displayName: 'Emir', currentStreak: 5, paused: true)));
    expect(find.text('🌴'), findsOneWidget);
    expect(find.text('🔥'), findsNothing);
  });

  testWidgets('tarnished + at-risk renders overlays', (tester) async {
    await tester.pumpWidget(wrap(MemberAvatar(
      displayName: 'Emir',
      currentStreak: 2,
      atRisk: true,
      lastActiveDate: DateTime.now().subtract(const Duration(days: 5)),
    )));
    expect(find.text('⚠'), findsOneWidget);
    expect(find.byType(ColorFiltered), findsWidgets);
  });
}
