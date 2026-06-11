import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/squad.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// shared_preferences key for the last squad a proof photo was shared to.
const kProofLastSquadKey = 'proof.last_squad_id';

/// Bottom sheet to pick which squad a proof photo goes to. Selecting persists
/// the choice and pops the chosen squad id.
class SquadPickerSheet extends StatelessWidget {
  final List<Squad> squads;
  final String selectedId;
  const SquadPickerSheet({super.key, required this.squads, required this.selectedId});

  static Future<String?> show(BuildContext context,
          {required List<Squad> squads, required String selectedId}) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.surface3,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
        builder: (_) => SquadPickerSheet(squads: squads, selectedId: selectedId),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: Spacing.s8),
        Center(
          child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(2))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s12, Spacing.s16, Spacing.s8),
          child: Text('SHARE TO', style: AppText.caption),
        ),
        for (final s in squads)
          ListTile(
            title: Text(s.name, style: AppText.bodyL),
            subtitle: Text('${s.memberCount} members', style: AppText.caption),
            trailing: s.id == selectedId
                ? const Icon(LucideIcons.checkCircle2, color: AppColors.squadBlue, size: 20)
                : null,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(kProofLastSquadKey, s.id);
              if (context.mounted) Navigator.pop(context, s.id);
            },
          ),
        const SizedBox(height: Spacing.s8),
      ]),
    );
  }
}
