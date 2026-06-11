import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Month grid (weeks start Monday). Cells are minimal per the canon: a bodyL
/// day number, up to 3 colored dots for categories with goals that day, and
/// the activity summary collapsed to a small meal count. Today gets a 12%
/// calendarAmber tint. Tapping a day opens the Day view.
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
            child: Center(child: Text(l, style: AppText.caption)),
          ),
      ]),
      const SizedBox(height: Spacing.s4),
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

    // Up to 3 distinct goal colors as dots — categories present that day.
    final dotColors = <Color>[];
    for (final o in occ) {
      if (!dotColors.contains(o.goal.color)) dotColors.add(o.goal.color);
      if (dotColors.length == 3) break;
    }

    return GestureDetector(
      onTap: () => onTapDay(day),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.all(Spacing.s4),
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.calendarAmber.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Column(children: [
          Text('${day.day}',
              style: AppText.tabular(AppText.bodyL.copyWith(
                  fontSize: 14,
                  color: isToday
                      ? AppColors.calendarAmber
                      : (inMonth
                          ? AppColors.textPrimary
                          : AppColors.textDisabled)))),
          const SizedBox(height: Spacing.s4),
          if (dotColors.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final c in dotColors)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: c),
                ),
            ]),
          const Spacer(),
          if (act != null && act.mealCount > 0)
            Text('${act.mealCount}',
                style: AppText.tabular(AppText.caption
                    .copyWith(fontSize: 9, color: AppColors.textTertiary))),
        ]),
      ),
    );
  }
}
