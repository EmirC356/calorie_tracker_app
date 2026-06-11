import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Scope chosen when editing or deleting a recurring goal.
enum RecurringEditScope { onlyThis, thisAndFuture, allInSeries }

/// Prompts "Only this / This and future / All in the series" for a recurring
/// goal. Returns null if dismissed. [verb] is "edit" or "delete".
Future<RecurringEditScope?> showRecurringEditChoice(BuildContext context,
    {required String verb}) {
  return showModalBottomSheet<RecurringEditScope>(
    context: context,
    backgroundColor: AppColors.surface3,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
    ),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.s20, Spacing.s20, Spacing.s20, Spacing.s8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
                '${verb[0].toUpperCase()}${verb.substring(1)} recurring goal'
                    .toUpperCase(),
                style: AppText.caption),
          ),
        ),
        _tile(context, 'Only this occurrence', LucideIcons.circleDot,
            RecurringEditScope.onlyThis),
        _tile(context, 'This and future occurrences', LucideIcons.fastForward,
            RecurringEditScope.thisAndFuture),
        _tile(context, 'All occurrences in the series', LucideIcons.infinity,
            RecurringEditScope.allInSeries),
        const SizedBox(height: Spacing.s8),
      ]),
    ),
  );
}

Widget _tile(BuildContext context, String label, IconData icon,
        RecurringEditScope scope) =>
    ListTile(
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(label, style: AppText.bodyM),
      onTap: () => Navigator.pop(context, scope),
    );
