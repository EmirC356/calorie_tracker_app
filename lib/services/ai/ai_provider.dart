import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/nutrient.dart';
import '../../models/ai_errors.dart';

/// One pluggable AI backend (Gemini, OpenAI, Anthropic). All providers share the
/// same public surface so [AiService] can route to whichever is active.
abstract class AiProvider {
  /// Estimate nutrition for a described food. [grams] <= 0 means "as eaten /
  /// unspecified portion" (the free-text QUICK flow); > 0 anchors the estimate.
  Future<NutrientInfo> analyzeFoodText(String name, double grams);

  Future<double> estimateCaloriesBurned({
    required String activity,
    required int minutes,
    required String intensity,
    required double bodyWeightKg,
  });

  Future<String> getMealAdvice(String query);

  /// Sends a minimal prompt. Returns true on a 2xx with parseable output;
  /// throws [AiRequestException] (with a user-friendly message) on auth/network
  /// failure, and [NoApiKeyException] when no key is set.
  Future<bool> testConnection();

  bool get supportsVision;
  String get displayName;
  String get providerKey;
  List<String> get availableModels;
}

/// Shared prompt construction, JSON extraction and HTTP plumbing. Concrete
/// providers only implement [complete] (the provider-specific request/response)
/// and the metadata getters.
abstract class BaseAiProvider implements AiProvider {
  final String? apiKey;
  final String model;
  final http.Client client;

  BaseAiProvider({this.apiKey, required this.model, http.Client? client})
      : client = client ?? http.Client();

  /// Provider-specific completion. Throws [AiRequestException] on non-2xx.
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = false,
    int maxTokens = 500,
    double temperature = 0.7,
  });

  void requireKey() {
    if (apiKey == null || apiKey!.trim().isEmpty) {
      throw NoApiKeyException(providerKey);
    }
  }

  @override
  Future<NutrientInfo> analyzeFoodText(String name, double grams) async {
    requireKey();
    final portion = grams > 0 ? ' for a ${grams.toStringAsFixed(0)} g portion' : ' as eaten';
    final raw = await complete(
      systemPrompt:
          'You are a precise nutrition calculator. Estimate the total nutrition '
          'for the described meal$portion. Return ONLY valid JSON — no markdown, '
          'no explanation.',
      userPrompt:
          'Nutrition facts for: "$name"$portion\nReturn exactly: '
          '{"calories":0,"protein":0,"carbohydrates":0,"fat":0,"fiber":0,"sugar":0}',
      jsonMode: true,
      maxTokens: 512,
      temperature: 0.1,
    );
    return NutrientInfo.fromJson(extractJsonObject(raw));
  }

  @override
  Future<double> estimateCaloriesBurned({
    required String activity,
    required int minutes,
    required String intensity,
    required double bodyWeightKg,
  }) async {
    requireKey();
    final raw = await complete(
      systemPrompt:
          'You are an exercise physiologist. Estimate calories burned using '
          'MET-based reasoning, adjusting for the stated intensity '
          '(low/medium/high). Return ONLY valid JSON — no markdown, no explanation.',
      userPrompt:
          'Calories burned for: activity "$activity", duration $minutes minutes, '
          'intensity "$intensity", body weight ${bodyWeightKg.toStringAsFixed(1)} kg.\n'
          'Return exactly: {"calories":0}',
      jsonMode: true,
      maxTokens: 200,
      temperature: 0.1,
    );
    return (extractJsonObject(raw)['calories'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<String> getMealAdvice(String query) async {
    requireKey();
    return complete(
      systemPrompt:
          'You are a professional nutritionist and meal prep advisor. Provide '
          'helpful, practical, science-based advice. Keep responses concise '
          '(2-3 paragraphs).',
      userPrompt: query,
      maxTokens: 500,
      temperature: 0.7,
    );
  }

  @override
  Future<bool> testConnection() async {
    requireKey();
    final raw = await complete(
      systemPrompt: 'Reply with a single short word.',
      userPrompt: 'Say "ok".',
      maxTokens: 16,
      temperature: 0,
    );
    return raw.trim().isNotEmpty;
  }

  /// Pulls the first JSON object out of a model response (handles stray prose or
  /// markdown fences around the JSON — the Anthropic fallback path).
  static Map<String, dynamic> extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) {
      throw AiRequestException('Could not parse JSON from response: "${raw.trim()}"');
    }
    return jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
  }
}

/// Maps an HTTP failure to a short, user-facing message for the "Test key" flow.
String friendlyHttpError(String provider, int status, String body) {
  if (status == 401 || status == 403) {
    return '$status Unauthorized — check the key.';
  }
  if (status == 429) return '429 Rate limited — try again shortly.';
  final trimmed = body.length > 200 ? '${body.substring(0, 200)}…' : body;
  return '$provider error $status: $trimmed';
}
