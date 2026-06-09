import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/calendar/goal_chip.dart';
import '../../widgets/calendar/day_summary_chip.dart';
import 'goal_detail_sheet.dart';

/// Month grid (weeks start Monday). Each cell shows the day number, up to 3
/// compact goal chips (with a "+N" overflow), and up to 2 activity summary
/// chips. Tapping a day opens the Day view.
class CalendarMonthView extends StatelessWidget {
  final DateTime month; // any date within the month
  final Map<String, DayActivity> activity;
  final void Function(DateTime day) onTapDay;

  const CalendarMonthView({
    super.key,
    required this.month,
    required this.activity,
    required this.onTapDay,
  });

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    final first = DateTime(month.year, month.month, 1);
    final gridStart = mondayOf(first);
    final today = dateOnly(DateTime.now());
    // Enough rows to cover the month (5 or 6 weeks).
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final span = mondayOf(first).difference(first).inDays.abs() + daysInMonth;
    final rows = (span / 7).ceil().clamp(5, 6);

    return Column(children: [
      Row(children: [
        for (final l in _weekdayLabels)
          Expanded(
            child: Center(
              child: Text(l, style: const TextStyle(color: kTextDim, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Expanded(
        child: Column(
          children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: _cell(context, provider, gridStart.add(Duration(days: r * 7 + c)), today),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _cell(BuildContext context, GoalProvider provider, DateTime day, DateTime today) {
    final inMonth = day.month == month.month;
    final isToday = dateOnly(day) == today;
    final occ = provider.occurrencesOn(day);
    final act = activity[ymd(day)];

    return GestureDetector(
      onTap: () => onTapDay(day),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isToday ? kAmber.withValues(alpha: 0.10) : kCard,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: isToday ? kAmber : kBorderDim),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${day.day}',
              style: TextStyle(
                  color: isToday
                      ? kAmber
                      : (inMonth ? kText : kTextDim.withValues(alpha: 0.4)),
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
          Expanded(
            child: ClipRect(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final o in occ.take(3))
                  GoalChip(
                    goal: o.goal,
                    status: o.row?.status ?? OccurrenceStatus.open,
                    compact: true,
                    onTap: () => showGoalDetailSheet(context, goal: o.goal, date: day),
                  ),
                if (occ.length > 3)
                  Text('+${occ.length - 3}',
                      style: const TextStyle(color: kTextDim, fontSize: 9)),
                if (act != null) ...DaySummaryChip.forActivity(act).take(2),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
