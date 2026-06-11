import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/squad_provider.dart';
import '../../services/squad_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Per-user "Squad notifications" master switches + quiet hours, written to
/// users/{uid}/notificationPrefs/master (every Cloud Function consults it).
/// Defaults are ON / 23:00–07:00 when the doc is missing.
class SquadNotificationsScreen extends StatelessWidget {
  const SquadNotificationsScreen({super.key});

  static const _toggles = [
    ('squadAttributed', 'Squad pushes', 'Goal hits, full-squad days, group goals, pauses'),
    ('personalPress', 'Personal nudges', 'Gentle "your streak ended — start a new one" pushes'),
    ('broadcastStreakLoss', "Squadmates' streak losses", 'When a teammate breaks a long streak'),
    ('retros', 'Weekly retro', 'The Sunday squad recap'),
  ];

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) {
      return Scaffold(
          body: Center(
              child: Text('Sign in to manage notifications',
                  style: AppText.bodyM
                      .copyWith(color: AppColors.textSecondary))));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Squad Notifications')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: service.watchNotificationPrefs(uid),
        builder: (context, snap) {
          final p = snap.data ?? const <String, dynamic>{};
          bool on(String k) => (p[k] as bool?) ?? true;
          final qStart = (p['quietHoursStart'] as String?) ?? '23:00';
          final qEnd = (p['quietHoursEnd'] as String?) ?? '07:00';
          return ListView(padding: const EdgeInsets.all(Spacing.s16), children: [
            for (final (key, title, sub) in _toggles) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.squadBlue,
                title: Text(title, style: AppText.bodyL),
                subtitle: Text(sub,
                    style: AppText.bodyM
                        .copyWith(color: AppColors.textSecondary)),
                value: on(key),
                onChanged: (v) => service.setNotificationPref(uid, key, v),
              ),
              const Divider(color: AppColors.surface2),
            ],
            const SizedBox(height: Spacing.s12),
            Text('QUIET HOURS', style: AppText.caption),
            const SizedBox(height: Spacing.s4),
            Text('No squad pushes during this window (dropped, not queued).',
                style:
                    AppText.bodyM.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: Spacing.s8),
            Row(children: [
              Expanded(child: _timeRow(context, service, uid, 'Start', 'quietHoursStart', qStart)),
              const SizedBox(width: Spacing.s12),
              Expanded(child: _timeRow(context, service, uid, 'End', 'quietHoursEnd', qEnd)),
            ]),
          ]);
        },
      ),
    );
  }

  Widget _timeRow(BuildContext context, SquadService service, String uid, String label, String key, String value) {
    return OutlinedButton(
      onPressed: () async {
        final parts = value.split(':');
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 23, minute: int.tryParse(parts.last) ?? 0),
        );
        if (picked != null) {
          final hh = picked.hour.toString().padLeft(2, '0');
          final mm = picked.minute.toString().padLeft(2, '0');
          await service.setNotificationPref(uid, key, '$hh:$mm');
        }
      },
      style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.squadBlue,
          side: const BorderSide(color: AppColors.squadBlue, width: 1.5)),
      child: Text('$label: $value'),
    );
  }
}
