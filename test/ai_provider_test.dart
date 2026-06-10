import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/models/ai_errors.dart';
import 'package:calorie_tracker_app/services/ai_service.dart';
import 'package:calorie_tracker_app/services/ai/gemini_provider.dart';
import 'package:calorie_tracker_app/services/ai/openai_provider.dart';
import 'package:calorie_tracker_app/services/ai/anthropic_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('provider request shape + parsing', () {
    test('Gemini: endpoint, thinkingBudget 0 + json mime, parses nutrients', () async {
      late http.Request req;
      final client = MockClient((r) async {
        req = r;
        return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"calories":600,"protein":45,"carbohydrates":60,"fat":12,"fiber":4,"sugar":2}'}
                    ]
                  }
                }
              ]
            }),
            200);
      });
      final p = GeminiProvider(apiKey: 'AIzaTEST', model: 'gemini-2.5-flash', client: client);
      final n = await p.analyzeFoodText('chicken breast', 200);

      expect(req.url.toString(), contains('models/gemini-2.5-flash:generateContent'));
      expect(req.url.toString(), contains('key=AIzaTEST'));
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['generationConfig']['thinkingConfig']['thinkingBudget'], 0);
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      expect(n.calories, 600);
      expect(n.protein, 45);
    });

    test('OpenAI: chat completions, bearer auth, json_object, parses', () async {
      late http.Request req;
      final client = MockClient((r) async {
        req = r;
        return http.Response(
            jsonEncode({
              'choices': [
                {'message': {'content': '{"calories":300,"protein":20,"carbohydrates":30,"fat":5,"fiber":2,"sugar":1}'}}
              ]
            }),
            200);
      });
      final p = OpenAiProvider(apiKey: 'sk-TEST', model: 'gpt-4o-mini', client: client);
      final n = await p.analyzeFoodText('white rice', 150);

      expect(req.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(req.headers['Authorization'], 'Bearer sk-TEST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4o-mini');
      expect(body['response_format']['type'], 'json_object');
      expect(n.calories, 300);
    });

    test('Anthropic: messages API, version header, extracts JSON from prose', () async {
      late http.Request req;
      final client = MockClient((r) async {
        req = r;
        return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'Sure: {"calories":250,"protein":10,"carbohydrates":20,"fat":8,"fiber":1,"sugar":3}'}
              ]
            }),
            200);
      });
      final p = AnthropicProvider(apiKey: 'sk-ant-TEST', model: 'claude-haiku-4-5-20251001', client: client);
      final n = await p.analyzeFoodText('protein bar', 0);

      expect(req.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(req.headers['anthropic-version'], '2023-06-01');
      expect(req.headers['x-api-key'], 'sk-ant-TEST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-haiku-4-5-20251001');
      expect(n.calories, 250); // pulled out of the prose-wrapped JSON
    });

    test('Gemini estimateCaloriesBurned parses {calories}', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'candidates': [
              {'content': {'parts': [{'text': '{"calories":275}'}]}}
            ]
          }),
          200));
      final p = GeminiProvider(apiKey: 'k', client: client);
      final kcal = await p.estimateCaloriesBurned(
          activity: 'running', minutes: 30, intensity: 'high', bodyWeightKg: 70);
      expect(kcal, 275);
    });
  });

  group('key + error handling', () {
    test('no key → NoApiKeyException', () {
      final p = GeminiProvider(apiKey: null, client: MockClient((_) async => http.Response('', 200)));
      expect(() => p.analyzeFoodText('x', 0), throwsA(isA<NoApiKeyException>()));
    });

    test('testConnection true on 2xx', () async {
      final p = OpenAiProvider(
          apiKey: 'sk',
          client: MockClient((_) async => http.Response(
              jsonEncode({'choices': [{'message': {'content': 'ok'}}]}), 200)));
      expect(await p.testConnection(), isTrue);
    });

    test('testConnection throws a friendly 401 message', () {
      final p = OpenAiProvider(
          apiKey: 'bad',
          client: MockClient((_) async => http.Response('{"error":"nope"}', 401)));
      expect(
          () => p.testConnection(),
          throwsA(predicate((e) => e is AiRequestException && e.toString().contains('401'))));
    });
  });

  group('AiService routing + persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('routes to the active provider; switching preserves other keys', () async {
      final svc = AiService();
      await svc.load();
      expect(svc.activeProviderKey, 'gemini');
      expect(svc.hasValidKey, isFalse);

      await svc.setApiKey('openai', 'sk-openai');
      await svc.setActiveProvider('openai', model: 'gpt-4o');
      expect(svc.activeProviderKey, 'openai');
      expect(svc.activeModel, 'gpt-4o');
      expect(svc.hasValidKey, isTrue);
      expect(svc.activeProvider.providerKey, 'openai');

      // Switch to gemini (no key) → not configured, but openai key preserved.
      await svc.setActiveProvider('gemini');
      expect(svc.hasValidKey, isFalse);
      expect(await svc.getApiKey('openai'), 'sk-openai');
    });

    test('migrates a legacy Gemini key on load', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_key': 'AIzaOLD'});
      final svc = AiService();
      await svc.load();
      expect(svc.hasValidKey, isTrue);
      expect(await svc.getApiKey('gemini'), 'AIzaOLD');
    });
  });
}
