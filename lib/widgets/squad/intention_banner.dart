import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/squad_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';

const _templates = ['Gym 3x', 'Stay under 2200 kcal', 'Log every meal', 'Read 30 min/day'];

/// Top-of-squad banner for this week's public commitment. Attention (amber,
/// from the orthogonal status palette) until set; squadBlue once declared.
/// Always squad-visible.
class IntentionBanner extends StatelessWidget {
  final String squadId;
  final String uid;
  const IntentionBanner({super.key, required this.squadId, required this.uid});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SquadProvider>().service;
    final week = isoWeekKey(DateTime.now());
    return StreamBuilder<SquadIntention?>(
      stream: service.watchMyIntention(squadId, week, uid),
      builder: (context, snap) {
        final mine = snap.data;
        final set = mine != null && mine.text.isNotEmpty;
        final accent =
            set ? AppColors.squadBlue : AppColors.statusInProgress;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.s16, Spacing.s12, Spacing.s16, 0),
          child: ColoredLeftBorderCard(
            accent: accent,
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.s16, vertical: Spacing.s12),
            onTap: mine?.isGraded == true
                ? null
                : () => _showSheet(context, week, mine),
            child: Row(children: [
              Icon(LucideIcons.flag, color: accent, size: 18),
              const SizedBox(width: Spacing.s12),
              Expanded(
                child: Text(
                  set
                      ? "This week: ${mine.text}"
                      : "Set this week's intention — visible to all squadmates",
                  style: AppText.bodyM,
                ),
              ),
              if (mine?.isGraded != true)
                const Icon(LucideIcons.chevronRight,
                    color: AppColors.textTertiary, size: 18),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _showSheet(BuildContext context, String week, SquadIntention? current) async {
    final service = context.read<SquadProvider>().service;
    final ctrl = TextEditingController(text: current?.text ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: Spacing.s20,
            right: Spacing.s20,
            top: Spacing.s20,
            bottom: Spacing.s20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This week, I will…', style: AppText.titleM),
                const SizedBox(height: Spacing.s4),
                Text('Visible to all squadmates.',
                    style:
                        AppText.bodyM.copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: Spacing.s12),
                Wrap(spacing: Spacing.s8, runSpacing: Spacing.s8, children: [
                  for (final t in _templates)
                    ActionChip(
                      label: Text(t, style: AppText.bodyS),
                      onPressed: () => setState(() => ctrl.text = t),
                    ),
                ]),
                const SizedBox(height: Spacing.s12),
                TextField(
                  controller: ctrl,
                  maxLength: 80,
                  style: AppText.bodyM,
                  decoration:
                      const InputDecoration(hintText: 'or write your own…'),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.squadBlue,
                      foregroundColor: AppColors.surface0,
                    ),
                    onPressed: () async {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      await service.setIntention(
                          squadId, week, SquadIntention(uid: uid, text: text));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('COMMIT'),
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}
