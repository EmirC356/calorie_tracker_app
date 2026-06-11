import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/snapshot_service.dart';
import '../../providers/snapshot_provider.dart';
import '../../theme/app_theme.dart';

/// (value, emoji, label, color) for the three one-tap check-in states.
const List<(String, String, String, Color)> kCheckinOptions = [
  ('onIt', '😎', 'On it', Color(0xFF4CC38A)),
  ('offTrack', '😬', 'Off track', kAmber),
  ('cheatDay', '🍕', 'Cheat day', kOrange),
];

Color checkinColor(String? v) => switch (v) {
  'onIt' => const Color(0xFF4CC38A),
  'offTrack' => kAmber,
  'cheatDay' => kOrange,
  _ => kBorderDim, // grey = didn't check in (a visible signal in itself)
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
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kNavy, width: 1)),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("How's today going?",
            style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          for (final (val, emoji, label, color) in kCheckinOptions)
            GestureDetector(
              onTap: () async {
                await db.setCheckin(today, val);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) context.read<SnapshotProvider>().pushNow();
              },
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: current == val ? color.withValues(alpha: 0.25) : kCard,
                    border: Border.all(color: color, width: current == val ? 2 : 1),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 30)),
                ),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
