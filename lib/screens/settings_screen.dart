import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ai_service.dart';
import '../services/prefs.dart';
import '../services/backup_service.dart';
import '../providers/auth_provider.dart';
import '../providers/squad_provider.dart';
import '../theme/app_theme.dart';
import 'settings/api_key_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _goalNotifs = true;

  @override
  void initState() {
    super.initState();
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

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await BackupService().writeBackupFile();
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Calorie Tracker backup');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['json']);
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
            'This REPLACES all current meals, exercises, weight and goals on '
            'this device with the contents of the backup. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore', style: TextStyle(color: kNeonRed))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final json = await File(path).readAsString();
      await BackupService().importFromJsonString(json);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Backup restored'),
          content: const Text('Restart the app to load your restored data.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      navigator.maybePop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI PROVIDER', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Consumer<AiService>(builder: (_, ai, __) {
            final configured = ai.hasValidKey;
            return Container(
              decoration: neonBox(configured ? kNeonGreen : kNeonYellow),
              child: ListTile(
                leading: Icon(configured ? Icons.smart_toy : Icons.warning_amber,
                    color: configured ? kNeonGreen : kNeonYellow),
                title: const Text('AI Provider', style: TextStyle(color: kText, fontSize: 15)),
                subtitle: Text(
                  configured
                      ? 'Configured (${ai.displayNameFor(ai.activeProviderKey)} · ${ai.activeModel})'
                      : 'Not configured — required for AI features',
                  style: TextStyle(color: configured ? kTextDim : kNeonYellow, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: kTextDim),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ApiKeyScreen())),
              ),
            );
          }),
          const SizedBox(height: 32),
          Text('DATA & BACKUP', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: neonBox(kCyan),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Export all meals, exercises, weight and goals to a JSON file you '
                'can save or move to a new phone. Your API key is never included. '
                'Importing replaces everything on this device.',
                style: TextStyle(color: kTextDim, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('EXPORT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importBackup,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('IMPORT'),
                  ),
                ),
              ]),
            ]),
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
