import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/calendar/goal_chip.dart';
import '../../widgets/calendar/day_summary_chip.dart';
import '../../widgets/calendar/goal_action_dialog.dart';

/// Seven-column week (Mon–Sun). Each column is a compact day cell; tapping it
/// opens the Day view for that date.
class CalendarWeekView extends StatelessWidget {
  final DateTime focused; // any date in the week
  final Map<String, DayActivity> activity;
  final void Function(DateTime day) onTapDay;

  const CalendarWeekView({
    super.key,
    required this.focused,
    required this.activity,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    final monday = mondayOf(focused);
    final today = dateOnly(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(child: _column(context, provider, monday.add(Duration(days: i)), today)),
      ],
    );
  }

  Widget _column(BuildContext context, GoalProvider provider, DateTime day, DateTime today) {
    final occ = provider.occurrencesOn(day);
    final act = activity[ymd(day)];
    final isToday = dateOnly(day) == today;
    return GestureDetector(
      onTap: () => onTapDay(day),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday ? kAmber.withValues(alpha: 0.08) : kCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isToday ? kAmber : kBorderDim),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Text(DateFormat('E').format(day).substring(0, 1),
                  style: TextStyle(color: isToday ? kAmber : kTextDim, fontSize: 11)),
              Text('${day.day}',
                  style: TextStyle(
                      color: isToday ? kAmber : kText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          const Divider(height: 1, color: kBorderDim),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(3),
              child: Column(children: [
                for (final o in occ)
                  GoalChip(
                    goal: o.goal,
                    status: o.row?.status ?? OccurrenceStatus.open,
                    compact: true,
                    onTap: () => showGoalActionDialog(context, goal: o.goal, date: day),
                  ),
                if (act != null) ...DaySummaryChip.forActivity(act),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
