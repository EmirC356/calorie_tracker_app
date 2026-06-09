import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/prefs.dart';
import '../providers/auth_provider.dart';
import '../providers/squad_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ctrl = TextEditingController();
  bool _isSet = false;
  bool _goalNotifs = true;

  @override
  void initState() {
    super.initState();
    _isSet = aiService.isInitialized;
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _goalNotifs = p.getBool(kGoalNotificationsEnabledPref) ?? true);
    });
  }

  Future<void> _setGoalNotifs(bool v) async {
    setState(() => _goalNotifs = v);
    // Capture provider references before any await (no context across the gap).
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    final service = context.read<SquadProvider>().service;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kGoalNotificationsEnabledPref, v);
    // Mirror to Firestore (best-effort) so the Cloud Functions honor it.
    if (uid != null) {
      try {
        await service.setGoalNotificationsEnabled(uid, v);
      } catch (_) {/* offline / signed out — local flag still saved */}
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an API key')));
      return;
    }
    await aiService.initialize(key);
    if (!mounted) return;
    setState(() => _isSet = true);
    _ctrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key updated!')));
  }

  Future<void> _clear() async {
    await aiService.clear();
    if (!mounted) return;
    setState(() => _isSet = false);
    _ctrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key cleared')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('API CONFIGURATION', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(_isSet ? kNeonGreen : kNeonYellow),
            child: Row(children: [
              Icon(_isSet ? Icons.check_circle : Icons.warning_amber, color: _isSet ? kNeonGreen : kNeonYellow),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isSet ? 'Gemini key is active' : 'No API key — AI features disabled',
                  style: TextStyle(color: _isSet ? kNeonGreen : kNeonYellow),
                ),
                if (_isSet && aiService.maskedKey != null)
                  Text(aiService.maskedKey!,
                    style: const TextStyle(color: kTextDim, fontSize: 12, fontFamily: 'monospace')),
              ])),
              if (_isSet)
                TextButton(
                  onPressed: _clear,
                  child: const Text('CLEAR', style: TextStyle(color: kNeonRed, fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('GEMINI API KEY', style: neonLabel(kCyan, size: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            obscureText: true,
            style: const TextStyle(color: kText),
            decoration: const InputDecoration(
              hintText: 'AIza...',
              labelText: 'Paste new key here',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('SAVE KEY', style: TextStyle(letterSpacing: 1.5)),
            ),
          ),
          const SizedBox(height: 32),
          Text('NOTIFICATIONS', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Container(
            decoration: neonBox(kAmber),
            child: SwitchListTile(
              activeThumbColor: kAmber,
              title: const Text('Goal notifications', style: TextStyle(color: kText, fontSize: 15)),
              subtitle: const Text('Morning brief at 8:00 and goal reminders',
                  style: TextStyle(color: kTextDim, fontSize: 12)),
              value: _goalNotifs,
              onChanged: _setGoalNotifs,
            ),
          ),
          const SizedBox(height: 32),
          Text('ABOUT', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(kBorderDim),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Calorie Tracker v2.0', style: neonLabel(kCyan)),
              const SizedBox(height: 8),
              const Text('Track meals, meal preps, exercises, and weight.\nPowered by Google Gemini for nutrition advice.',
                style: TextStyle(color: kTextDim, fontSize: 13, height: 1.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}
