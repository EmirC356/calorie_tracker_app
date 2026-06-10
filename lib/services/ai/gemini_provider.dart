import 'dart:convert';
import '../../models/ai_errors.dart';
import 'ai_provider.dart';

/// Google Gemini via the Generative Language REST API.
class GeminiProvider extends BaseAiProvider {
  GeminiProvider({super.apiKey, super.model = 'gemini-2.5-flash', super.client});

  @override
  String get providerKey => 'gemini';
  @override
  String get displayName => 'Google Gemini';
  @override
  bool get supportsVision => true;
  @override
  List<String> get availableModels => const ['gemini-2.5-flash', 'gemini-2.5-pro'];

  Uri get _endpoint => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = false,
    int maxTokens = 500,
    double temperature = 0.7,
  }) async {
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': userPrompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        // gemini-2.5-flash is a thinking model; reasoning tokens count against
        // maxOutputTokens. Disable thinking so the budget goes to the answer.
        'thinkingConfig': {'thinkingBudget': 0},
        if (jsonMode) 'responseMimeType': 'application/json',
      },
    });

    final response = await client.post(_endpoint,
        headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode != 200) {
      throw AiRequestException(
          friendlyHttpError('Gemini', response.statusCode, response.body));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const AiRequestException('Gemini returned no candidates.');
    }
    final parts = candidates.first['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw const AiRequestException('Gemini returned an empty response.');
    }
    return parts.map((p) => p['text'] ?? '').join();
  }
}
