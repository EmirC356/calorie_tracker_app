/// SharedPreferences key under which the Gemini API key is stored.
const String kGeminiKeyPref = 'gemini_api_key';

/// SharedPreferences key for the JSON-encoded [UserProfile].
const String kUserProfilePref = 'user_profile';

/// SharedPreferences key for the last goal-occurrence sweep date (`YYYY-MM-DD`).
/// Bounds how far back the end-of-period sweep finalizes occurrences.
const String kLastGoalSweepPref = 'last_goal_sweep_date';
