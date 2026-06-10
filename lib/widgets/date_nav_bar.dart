import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../theme/app_theme.dart';

/// A compact "‹ [date] ›" day navigator. The left arrow steps one day back, the
/// centre button shows the day ("Today" when current) and opens a date picker to
/// jump anywhere in the month, and the right arrow steps forward — disabled on
/// the current day (you can't browse the future).
class DateNavBar extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  final Color accent;

  const DateNavBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accent = kRed,
  });

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final sel = dateOnly(selected);
    final canForward = sel.isBefore(today);

    return Row(children: [
      IconButton(
        tooltip: 'Previous day',
        icon: Icon(Icons.chevron_left, color: accent),
        onPressed: () => onChanged(sel.subtract(const Duration(days: 1))),
      ),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: sel,
              firstDate: DateTime(2020),
              lastDate: today,
            );
            if (picked != null) onChanged(dateOnly(picked));
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.event, size: 16),
          label: Text(sel == today ? 'Today' : DateFormat('EEE, MMM d').format(sel)),
        ),
      ),
      IconButton(
        tooltip: 'Next day',
        icon: Icon(Icons.chevron_right, color: canForward ? accent : kTextDim),
        onPressed: canForward ? () => onChanged(sel.add(const Duration(days: 1))) : null,
      ),
    ]);
  }
}
