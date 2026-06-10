import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/widgets/squad/squad_member_avatar.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('streak 0 shows no flame', (tester) async {
    await tester.pumpWidget(host(const SquadMemberAvatar(photoURL: null, currentStreak: 0)));
    expect(find.text('🔥'), findsNothing);
  });

  testWidgets('a mid streak shows the flame + count', (tester) async {
    await tester.pumpWidget(host(const SquadMemberAvatar(photoURL: null, currentStreak: 5)));
    expect(find.text('🔥'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('high streak animates (pump, not settle) and shows count', (tester) async {
    await tester.pumpWidget(host(const SquadMemberAvatar(photoURL: null, currentStreak: 20)));
    await tester.pump(const Duration(milliseconds: 200)); // animation running
    expect(find.text('🔥'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.byType(ScaleTransition), findsWidgets); // tier ≥14 pulses the flame
  });

  testWidgets('streak over 999 caps the label', (tester) async {
    await tester.pumpWidget(host(const SquadMemberAvatar(photoURL: null, currentStreak: 1500)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('999+'), findsOneWidget);
  });

  testWidgets('paused shows 🌴 and no flame', (tester) async {
    await tester.pumpWidget(host(const SquadMemberAvatar(photoURL: null, currentStreak: 12, paused: true)));
    expect(find.text('🌴'), findsOneWidget);
    expect(find.text('🔥'), findsNothing);
  });

  testWidgets('inactive 3+ days (not paused) tarnishes the avatar', (tester) async {
    await tester.pumpWidget(host(SquadMemberAvatar(
      photoURL: null,
      currentStreak: 4,
      lastActiveDate: DateTime(2026, 6, 6),
      now: DateTime(2026, 6, 10),
    )));
    expect(find.byType(ColorFiltered), findsOneWidget); // greyscale wash
    expect(find.byType(Opacity), findsOneWidget);
  });

  testWidgets('at-risk with streak ≥3 shows the warning overlay', (tester) async {
    await tester.pumpWidget(host(const SquadMemberAvatar(
        photoURL: null, currentStreak: 5, atRiskFlag: true)));
    expect(find.text('⚠'), findsOneWidget);
  });

  testWidgets('at-risk with streak <3 shows no warning', (tester) async {
    await tester.pumpWidget(host(const SquadMemberAvatar(
        photoURL: null, currentStreak: 2, atRiskFlag: true)));
    expect(find.text('⚠'), findsNothing);
  });
}
