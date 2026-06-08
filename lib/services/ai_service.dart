import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nutrient.dart';
import 'prefs.dart';

class AIService {
  String? _apiKey;
  bool _isInitialized = false;

  static const _model = 'gemini-2.5-flash';
  static String _endpoint(String key) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$key';

  /// Sets the active key and persists it so it survives a cold start.
  Future<void> initialize(String apiKey) async {
    _apiKey = apiKey.trim();
    _isInitialized = _apiKey!.isNotEmpty;
    final prefs = await SharedPreferences.getInstance();
    if (_isInitialized) {
      await prefs.setString(kGeminiKeyPref, _apiKey!);
    } else {
      await prefs.remove(kGeminiKeyPref);
    }
  }

  /// Restores a previously saved key. Call once on app startup.
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kGeminiKeyPref);
    if (stored != null && stored.isNotEmpty) {
      _apiKey = stored;
      _isInitialized = true;
    }
  }

  /// Forgets the key in memory and on disk.
  Future<void> clear() async {
    _apiKey = null;
    _isInitialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kGeminiKeyPref);
  }

  bool get isInitialized => _isInitialized;

  /// A display-safe version of the key, e.g. `AIza••••NFSM`. Null if unset.
  String? get maskedKey {
    final k = _apiKey;
    if (k == null || k.isEmpty) return null;
    if (k.length <= 8) return '••••';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';
  }

  Future<String> getMealAdvice(String query) async {
    _requireInit();
    return _generate(
      systemPrompt:
          'You are a professional nutritionist and meal prep advisor. Provide helpful, practical, science-based advice. Keep responses concise (2-3 paragraphs).',
      userPrompt: query,
      maxTokens: 500,
      temperature: 0.7,
    );
  }

  Future<NutrientInfo> analyzeFoodText(String description) async {
    _requireInit();
    final raw = await _generate(
      systemPrompt:
          'You are a precise nutrition calculator. Estimate the total nutrition for the described meal as eaten. Return ONLY valid JSON — no markdown, no explanation.',
      userPrompt:
          'Nutrition facts for: "$description"\nReturn exactly: {"calories":0,"protein":0,"carbohydrates":0,"fat":0,"fiber":0,"sugar":0}',
      maxTokens: 512,
      temperature: 0.1,
      jsonMode: true,
    );

    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1) {
      throw Exception('Could not parse nutrition JSON. Got: "${raw.trim()}"');
    }
    final data = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    return NutrientInfo.fromJson(data);
  }

  Future<String> _generate({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 500,
    double temperature = 0.7,
    bool jsonMode = false,
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

    final response = await http.post(
      Uri.parse(_endpoint(_apiKey!)),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates');
    }
    final parts = candidates.first['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini returned an empty response');
    }
    return parts.map((p) => p['text'] ?? '').join();
  }

  void _requireInit() {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Set your Gemini API key in Settings.');
    }
  }
}

final aiService = AIService();
