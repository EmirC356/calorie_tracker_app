import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/snapshot_service.dart';
import '../../providers/snapshot_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// (value, emoji, label, color) for the three one-tap check-in states.
/// Check-in colors are data semantics, not section accents.
const List<(String, String, String, Color)> kCheckinOptions = [
  ('onIt', '😎', 'On it', AppColors.statusHit),
  ('offTrack', '😬', 'Off track', AppColors.statusInProgress),
  // TODO(ui): clarify cheat-day color — legacy kOrange now aliases
  // textTertiary; kept neutral until a token is decided.
  ('cheatDay', '🍕', 'Cheat day', AppColors.textTertiary),
];

Color checkinColor(String? v) => switch (v) {
  'onIt' => AppColors.statusHit,
  'offTrack' => AppColors.statusInProgress,
  'cheatDay' => AppColors.textTertiary,
  _ => AppColors.surface3, // grey = didn't check in (a visible signal in itself)
};

String checkinEmoji(String? v) =>
    kCheckinOptions.where((o) => o.$1 == v).map((o) => o.$2).firstOrNull ?? '○';

/// Bottom sheet with the 3 check-in buttons. Writes the local mirror and kicks a
/// snapshot push so the entry's `checkin` updates across squads.
Future<void> showCheckinSheet(BuildContext context) async {
  final today = SnapshotService.dateKey(DateTime.now());
  final db = DatabaseService();
  final current = await db.getCheckin(today);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface3,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(Spacing.s20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("How's today going?", style: AppText.titleM),
        const SizedBox(height: Spacing.s16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          for (final (val, emoji, label, color) in kCheckinOptions)
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                await db.setCheckin(today, val);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) context.read<SnapshotProvider>().pushNow();
              },
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.s12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface2,
                    // Selection per the focus rule: 1.5px border, no fill.
                    border: current == val
                        ? Border.all(
                            color: color, width: AppMotion.focusBorderWidth)
                        : null,
                    boxShadow:
                        current == val ? AppMotion.accentGlow(color) : null,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 30)),
                ),
                const SizedBox(height: Spacing.s8),
                Text(label, style: AppText.bodyS.copyWith(color: color)),
              ]),
            ),
        ]),
        const SizedBox(height: Spacing.s8),
      ]),
    ),
  );
}
