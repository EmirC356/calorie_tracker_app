import 'dart:convert';
import '../../models/ai_errors.dart';
import 'ai_provider.dart';

/// OpenAI via the Chat Completions API.
class OpenAiProvider extends BaseAiProvider {
  OpenAiProvider({super.apiKey, super.model = 'gpt-4o-mini', super.client});

  @override
  String get providerKey => 'openai';
  @override
  String get displayName => 'OpenAI';
  @override
  bool get supportsVision => true;
  @override
  List<String> get availableModels => const ['gpt-4o-mini', 'gpt-4o'];

  static final Uri _endpoint = Uri.parse('https://api.openai.com/v1/chat/completions');

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = false,
    int maxTokens = 500,
    double temperature = 0.7,
  }) async {
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    });

    final response = await client.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw AiRequestException(
          friendlyHttpError('OpenAI', response.statusCode, response.body));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const AiRequestException('OpenAI returned no choices.');
    }
    final content = choices.first['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw const AiRequestException('OpenAI returned an empty response.');
    }
    return content;
  }
}
