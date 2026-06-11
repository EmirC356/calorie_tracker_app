import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ai_service.dart';
import '../services/prefs.dart';
import '../services/backup_service.dart';
import '../services/streak_warning_service.dart';
import '../providers/auth_provider.dart';
import '../providers/squad_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'settings/api_key_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _goalNotifs = true;
  int _streakWarnHour = 21; // -1 = off

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          _goalNotifs = p.getBool(kGoalNotificationsEnabledPref) ?? true;
          _streakWarnHour = p.getInt(kStreakWarnHourPref) ?? 21;
        });
      }
    });
  }

  Future<void> _setStreakWarnHour(int hour) async {
    setState(() => _streakWarnHour = hour);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kStreakWarnHourPref, hour);
    await StreakWarningService.schedule(
        hour: hour, body: "Don't lose your streak — log today to keep it alive.");
  }

  String _hourLabel(int h) {
    if (h < 0) return 'Off';
    final ampm = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:00 $ampm';
  }

  Future<void> _pickStreakWarnTime() async {
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Streak warning time', style: AppText.titleM),
        children: [
          for (final h in [-1, 20, 21, 22])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, h),
              child: Text(
                _hourLabel(h),
                style: AppText.bodyL.copyWith(
                    color: h == _streakWarnHour
                        ? AppColors.healthRed
                        : AppColors.textPrimary),
              ),
            ),
        ],
      ),
    );
    if (choice != null) await _setStreakWarnHour(choice);
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
              child: const Text('Restore',
                  style: TextStyle(color: AppColors.statusMissed))),
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
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI PROVIDER', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          Consumer<AiService>(builder: (_, ai, __) {
            final configured = ai.hasValidKey;
            return _SettingsRow(
              icon: configured ? LucideIcons.bot : LucideIcons.alertTriangle,
              iconColor: configured
                  ? AppColors.textSecondary
                  : AppColors.statusInProgress,
              title: 'AI Provider',
              subtitle: configured
                  ? 'Configured (${ai.displayNameFor(ai.activeProviderKey)} · ${ai.activeModel})'
                  : 'Not configured — required for AI features',
              subtitleColor:
                  configured ? null : AppColors.statusInProgress,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ApiKeyScreen())),
            );
          }),
          const SizedBox(height: Spacing.s32),
          Text('DATA & BACKUP', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          Text(
            'Export all meals, exercises, weight and goals to a JSON file you '
            'can save or move to a new phone. Your API key is never included. '
            'Importing replaces everything on this device.',
            style: AppText.bodyM
                .copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: Spacing.s12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportBackup,
                icon: const Icon(LucideIcons.upload, size: 18),
                label: const Text('Export'),
              ),
            ),
            const SizedBox(width: Spacing.s12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importBackup,
                icon: const Icon(LucideIcons.download, size: 18),
                label: const Text('Import'),
              ),
            ),
          ]),
          const SizedBox(height: Spacing.s32),
          Text('NOTIFICATIONS', style: AppText.caption),
          const SizedBox(height: Spacing.s8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.healthRed,
            title: Text('Goal notifications', style: AppText.bodyL),
            subtitle: Text('Morning brief at 8:00 and goal reminders',
                style: AppText.bodyM
                    .copyWith(color: AppColors.textSecondary)),
            value: _goalNotifs,
            onChanged: _setGoalNotifs,
          ),
          const Divider(color: AppColors.surface2),
          _SettingsRow(
            icon: LucideIcons.flame,
            title: 'Streak warning',
            subtitle: _streakWarnHour < 0
                ? 'Off'
                : 'Daily nudge at ${_hourLabel(_streakWarnHour)} if a squad streak is at risk',
            trailing: Text(
              _hourLabel(_streakWarnHour),
              style: AppText.tabular(
                  AppText.bodyM.copyWith(color: AppColors.healthRed)),
            ),
            onTap: _pickStreakWarnTime,
          ),
          const SizedBox(height: Spacing.s32),
          Text('ABOUT', style: AppText.caption),
          const SizedBox(height: Spacing.s12),
          Text('Calorie Tracker v2.0', style: AppText.titleM),
          const SizedBox(height: Spacing.s8),
          Text(
            'Track meals, meal preps, exercises, and weight.\nPowered by Google Gemini for nutrition advice.',
            style: AppText.bodyM
                .copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ]),
      ),
    );
  }
}

/// Canonical settings row: bodyL title, bodyM textSecondary subtitle, lucide
/// chevron trailing, no card container (design/system.md settings pattern).
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: iconColor ?? AppColors.textSecondary),
      title: Text(title, style: AppText.bodyL),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: AppText.bodyM.copyWith(
                  color: subtitleColor ?? AppColors.textSecondary)),
      trailing: trailing ??
          const Icon(LucideIcons.chevronRight,
              size: 18, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}
