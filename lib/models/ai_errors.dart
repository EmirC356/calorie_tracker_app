/// Thrown when an AI provider method is called but no API key is configured for
/// the active provider. The UI catches this to render the lock overlay.
class NoApiKeyException implements Exception {
  final String providerKey;
  const NoApiKeyException(this.providerKey);
  @override
  String toString() => 'No API key configured for $providerKey.';
}

/// Thrown by a provider when a request fails (non-2xx or unusable response),
/// carrying a user-friendly [message] for the "Test key" UI.
class AiRequestException implements Exception {
  final String message;
  const AiRequestException(this.message);
  @override
  String toString() => message;
}
