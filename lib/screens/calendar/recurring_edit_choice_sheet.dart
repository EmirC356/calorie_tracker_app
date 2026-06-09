import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Scope chosen when editing or deleting a recurring goal.
enum RecurringEditScope { onlyThis, thisAndFuture, allInSeries }

/// Prompts "Only this / This and future / All in the series" for a recurring
/// goal. Returns null if dismissed. [verb] is "edit" or "delete".
Future<RecurringEditScope?> showRecurringEditChoice(BuildContext context,
    {required String verb}) {
  return showModalBottomSheet<RecurringEditScope>(
    context: context,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: kAmber, width: 1),
    ),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${verb[0].toUpperCase()}${verb.substring(1)} recurring goal',
                style: neonLabel(kAmber, size: 15)),
          ),
        ),
        _tile(context, 'Only this occurrence', Icons.looks_one, RecurringEditScope.onlyThis),
        _tile(context, 'This and future occurrences', Icons.fast_forward, RecurringEditScope.thisAndFuture),
        _tile(context, 'All occurrences in the series', Icons.all_inclusive, RecurringEditScope.allInSeries),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

Widget _tile(BuildContext context, String label, IconData icon, RecurringEditScope scope) =>
    ListTile(
      leading: Icon(icon, color: kAmber),
      title: Text(label, style: const TextStyle(color: kText, fontSize: 14)),
      onTap: () => Navigator.pop(context, scope),
    );
