/// SharedPreferences key under which the legacy Gemini API key is stored.
/// Migrated to [aiKeyPref]('gemini') on first load of the multi-provider AI.
const String kGeminiKeyPref = 'gemini_api_key';

/// Active AI provider key ('gemini' | 'openai' | 'anthropic').
const String kAiActiveProviderPref = 'ai.active_provider';

/// Per-provider selected model id.
String aiModelPref(String providerKey) => 'ai.active_model.$providerKey';

/// Per-provider API key (device-local; never written to Firestore).
String aiKeyPref(String providerKey) => 'ai.key.$providerKey';

/// SharedPreferences key for the JSON-encoded [UserProfile].
const String kUserProfilePref = 'user_profile';

/// SharedPreferences key for the last goal-occurrence sweep date (`YYYY-MM-DD`).
/// Bounds how far back the end-of-period sweep finalizes occurrences.
const String kLastGoalSweepPref = 'last_goal_sweep_date';

/// SharedPreferences flag: whether the one-time "squad-visible goal" privacy
/// explainer has been shown.
const String kSquadVisiblePrivacyShownPref = 'squad_visible_privacy_shown';

/// SharedPreferences flag: the global "Goal notifications" toggle (morning brief
/// + reminders). Defaults to on; mirrored to Firestore for the Cloud Functions.
const String kGoalNotificationsEnabledPref = 'goal_notifications_enabled';
