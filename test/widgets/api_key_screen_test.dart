import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/services/ai_service.dart';
import 'package:calorie_tracker_app/screens/settings/api_key_screen.dart';

void main() {
  Widget wrap(AiService ai) => ChangeNotifierProvider<AiService>.value(
        value: ai,
        child: const MaterialApp(home: ApiKeyScreen()),
      );

  testWidgets('no key → "Not configured" pill and no Clear button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ai = AiService(client: MockClient((_) async => http.Response('', 200)));
    await ai.load();

    await tester.pumpWidget(wrap(ai));

    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('CLEAR KEY'), findsNothing);
  });

  testWidgets('successful test flips pill to Configured and reveals Clear', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Default active provider is Gemini → return a Gemini-shaped 200.
    final ai = AiService(client: MockClient((_) async => http.Response(
        jsonEncode({
          'candidates': [
            {'content': {'parts': [{'text': 'ok'}]}}
          ]
        }),
        200)));
    await ai.load();

    await tester.pumpWidget(wrap(ai));
    await tester.enterText(find.byType(TextField), 'AIzaGOODKEY');
    await tester.pump();
    await tester.tap(find.text('TEST KEY'));
    await tester.pumpAndSettle();

    expect(ai.hasValidKey, isTrue);
    expect(find.text('Configured'), findsOneWidget);
    expect(find.text('CLEAR KEY'), findsOneWidget);
    expect(find.text('Key works'), findsWidgets);
  });

  testWidgets('failed test (401) does NOT persist the key', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ai = AiService(client: MockClient((_) async => http.Response('{"error":"bad"}', 401)));
    await ai.load();

    await tester.pumpWidget(wrap(ai));
    await tester.enterText(find.byType(TextField), 'AIzaBADKEY');
    await tester.pump();
    await tester.tap(find.text('TEST KEY'));
    await tester.pumpAndSettle();

    expect(ai.hasValidKey, isFalse);
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.textContaining('401'), findsWidgets);
  });
}
