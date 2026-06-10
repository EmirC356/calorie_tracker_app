import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/widgets/ai/blocked_ai_overlay.dart';

void main() {
  Widget host({required bool blocked, required VoidCallback onTap}) => MaterialApp(
        home: Scaffold(
          body: BlockedAiOverlay(
            isBlocked: blocked,
            child: Center(
              child: ElevatedButton(onPressed: onTap, child: const Text('TAP ME')),
            ),
          ),
        ),
      );

  testWidgets('blocked: scrim shows the CTA and the child is not tappable',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(blocked: true, onTap: () => taps++));

    expect(find.text('AI features locked'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);

    // The button is behind the ModalBarrier → the tap is absorbed.
    await tester.tap(find.text('TAP ME'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('not blocked: no scrim and the child is fully interactive',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(blocked: false, onTap: () => taps++));

    expect(find.text('Open Settings'), findsNothing);
    expect(find.text('AI features locked'), findsNothing);

    await tester.tap(find.text('TAP ME'));
    await tester.pump();
    expect(taps, 1);
  });
}
