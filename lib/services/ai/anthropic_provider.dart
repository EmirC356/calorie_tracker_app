import 'dart:convert';
import '../../models/ai_errors.dart';
import 'ai_provider.dart';

/// Anthropic Claude via the Messages API. JSON is enforced by prompt
/// instruction + the shared extractJsonObject fallback (the Messages API has no
/// native json_object mode).
class AnthropicProvider extends BaseAiProvider {
  AnthropicProvider({super.apiKey, super.model = 'claude-haiku-4-5-20251001', super.client});

  @override
  String get providerKey => 'anthropic';
  @override
  String get displayName => 'Anthropic Claude';
  @override
  bool get supportsVision => true;
  @override
  List<String> get availableModels =>
      const ['claude-haiku-4-5-20251001', 'claude-sonnet-4-6'];

  static final Uri _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = false,
    int maxTokens = 500,
    double temperature = 0.7,
  }) async {
    // The Messages API has no json_object mode; reinforce JSON-only via prompt.
    final system = jsonMode
        ? '$systemPrompt\nRespond with ONLY the raw JSON object, nothing else.'
        : systemPrompt;

    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'system': system,
      'messages': [
        {'role': 'user', 'content': userPrompt},
      ],
    });

    final response = await client.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey ?? '',
        'anthropic-version': '2023-06-01',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw AiRequestException(
          friendlyHttpError('Anthropic', response.statusCode, response.body));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) {
      throw const AiRequestException('Anthropic returned no content.');
    }
    final text = content
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] ?? '')
        .join();
    if (text.isEmpty) {
      throw const AiRequestException('Anthropic returned an empty response.');
    }
    return text;
  }
}
