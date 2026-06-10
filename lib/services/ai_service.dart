import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nutrient.dart';
import 'prefs.dart';
import 'ai/ai_provider.dart';
import 'ai/gemini_provider.dart';
import 'ai/openai_provider.dart';
import 'ai/anthropic_provider.dart';

/// Strict BYO (bring-your-own-key) AI facade over multiple providers. Routes the
/// app's AI calls to the active provider, holds per-provider keys/models on
/// device (shared_preferences only — never Firestore), and notifies listeners so
/// the lock overlay reacts the instant a key is configured.
class AiService extends ChangeNotifier {
  final http.Client? _client; // injected in tests
  AiService({http.Client? client}) : _client = client;

  static const List<String> providerKeys = ['gemini', 'openai', 'anthropic'];
  static const Map<String, String> _defaultModel = {
    'gemini': 'gemini-2.5-flash',
    'openai': 'gpt-4o-mini',
    'anthropic': 'claude-haiku-4-5-20251001',
  };

  String _activeProviderKey = 'gemini';
  final Map<String, String> _keys = {}; // providerKey -> api key
  final Map<String, String> _models = {}; // providerKey -> selected model

  // ── Active selection ────────────────────────────────────────────────────────

  String get activeProviderKey => _activeProviderKey;
  String get activeModel => _models[_activeProviderKey] ?? _defaultModel[_activeProviderKey]!;
  AiProvider get activeProvider => _build(_activeProviderKey);

  /// True iff a non-empty key is persisted for the *active* provider.
  bool get hasValidKey {
    final k = _keys[_activeProviderKey];
    return k != null && k.trim().isNotEmpty;
  }

  AiProvider _build(String pk) {
    final key = _keys[pk];
    final model = _models[pk] ?? _defaultModel[pk]!;
    switch (pk) {
      case 'openai':
        return OpenAiProvider(apiKey: key, model: model, client: _client);
      case 'anthropic':
        return AnthropicProvider(apiKey: key, model: model, client: _client);
      default:
        return GeminiProvider(apiKey: key, model: model, client: _client);
    }
  }

  /// Metadata helpers for the settings UI (no key required).
  AiProvider providerMeta(String pk) => _build(pk);
  List<String> modelsFor(String pk) => _build(pk).availableModels;
  String displayNameFor(String pk) => _build(pk).displayName;
  String modelFor(String pk) => _models[pk] ?? _defaultModel[pk]!;
  bool hasKeyFor(String pk) {
    final k = _keys[pk];
    return k != null && k.trim().isNotEmpty;
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  /// Loads the active provider, per-provider models and keys. Migrates a legacy
  /// single Gemini key into the new per-provider slot. Call once on startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _activeProviderKey = prefs.getString(kAiActiveProviderPref) ?? 'gemini';
    if (!providerKeys.contains(_activeProviderKey)) _activeProviderKey = 'gemini';

    for (final pk in providerKeys) {
      final k = prefs.getString(aiKeyPref(pk));
      if (k != null && k.isNotEmpty) _keys[pk] = k;
      final m = prefs.getString(aiModelPref(pk));
      if (m != null && _build(pk).availableModels.contains(m)) _models[pk] = m;
    }

    // Migrate the legacy single Gemini key → ai.key.gemini (one-time).
    final legacy = prefs.getString(kGeminiKeyPref);
    if (legacy != null && legacy.isNotEmpty && !_keys.containsKey('gemini')) {
      _keys['gemini'] = legacy;
      await prefs.setString(aiKeyPref('gemini'), legacy);
    }
    notifyListeners();
  }

  Future<void> setActiveProvider(String providerKey, {String? model}) async {
    if (!providerKeys.contains(providerKey)) return;
    _activeProviderKey = providerKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAiActiveProviderPref, providerKey);
    if (model != null && modelsFor(providerKey).contains(model)) {
      _models[providerKey] = model;
      await prefs.setString(aiModelPref(providerKey), model);
    }
    notifyListeners();
  }

  Future<void> setApiKey(String providerKey, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return clearApiKey(providerKey);
    _keys[providerKey] = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(aiKeyPref(providerKey), trimmed);
    if (providerKey == 'gemini') await prefs.setString(kGeminiKeyPref, trimmed);
    notifyListeners();
  }

  Future<String?> getApiKey(String providerKey) async => _keys[providerKey];

  Future<void> clearApiKey(String providerKey) async {
    _keys.remove(providerKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(aiKeyPref(providerKey));
    if (providerKey == 'gemini') await prefs.remove(kGeminiKeyPref);
    notifyListeners();
  }

  /// Tests the active provider's key. Returns true on success; throws
  /// [AiRequestException]/[NoApiKeyException] (with a message) on failure.
  Future<bool> testActiveKey() => activeProvider.testConnection();

  // ── App-facing AI calls (route to the active provider) ──────────────────────

  Future<NutrientInfo> analyzeFoodText(String description, {double grams = 0}) =>
      activeProvider.analyzeFoodText(description, grams);

  Future<double> estimateCaloriesBurned({
    required String activity,
    required int minutes,
    required String intensity,
    required double weightKg,
  }) =>
      activeProvider.estimateCaloriesBurned(
        activity: activity,
        minutes: minutes,
        intensity: intensity,
        bodyWeightKg: weightKg,
      );

  Future<String> getMealAdvice(String query) => activeProvider.getMealAdvice(query);

  // ── Legacy aliases (kept so existing call sites compile unchanged) ──────────

  bool get isInitialized => hasValidKey;

  /// A display-safe version of the active key, e.g. `AIza••••NFSM`.
  String? get maskedKey {
    final k = _keys[_activeProviderKey];
    if (k == null || k.isEmpty) return null;
    if (k.length <= 8) return '••••';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';
  }

  /// Seeds the Gemini key (used by the optional --dart-define=GEMINI_KEY).
  Future<void> initialize(String apiKey) async {
    await setActiveProvider('gemini');
    await setApiKey('gemini', apiKey);
  }

  Future<void> loadFromStorage() => load();
  Future<void> clear() => clearApiKey(_activeProviderKey);
}

final aiService = AiService();
