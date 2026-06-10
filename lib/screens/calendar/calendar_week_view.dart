import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/calendar/day_summary_chip.dart';
import '../../widgets/calendar/goal_action_dialog.dart';
import '../../widgets/calendar/calendar_status.dart';

/// A swipeable **3-day** window (was a static Mon–Sun grid). Each PageView page
/// shows three day columns, and a swipe advances by a **full window** (3 days):
/// {9,10,11} → {12,13,14}. The first window is centered on [initialDate] (today
/// on a fresh open).
///
/// Page→date conversion: the left column of page p is
/// `anchorLeft + (p - _kEpochPage) * 3` days, where `anchorLeft = initialDate −
/// 1` so page _kEpochPage shows [initial−1, initial, initial+1]. This gives
/// effectively infinite paging in both directions.
class CalendarWeekView extends StatefulWidget {
  final DateTime initialDate; // centered in the first window
  final void Function(DateTime day) onTapDay;

  const CalendarWeekView({
    super.key,
    required this.initialDate,
    required this.onTapDay,
  });

  @override
  State<CalendarWeekView> createState() => _CalendarWeekViewState();
}

const int _kEpochPage = 100000;

class _CalendarWeekViewState extends State<CalendarWeekView> {
  late final DateTime _anchorLeft; // left column of the initial (epoch) page
  late final PageController _controller;
  late DateTime _windowLeft; // left column of the current page
  Map<String, DayActivity> _activity = {};

  @override
  void initState() {
    super.initState();
    _anchorLeft = dateOnly(widget.initialDate).subtract(const Duration(days: 1));
    _windowLeft = _anchorLeft;
    _controller = PageController(initialPage: _kEpochPage, viewportFraction: 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActivity());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _leftForPage(int page) =>
      _anchorLeft.add(Duration(days: (page - _kEpochPage) * 3));

  /// Loads summary activity for the visible window ± a buffer (one DB pass).
  /// Guarded so a DB hiccup never blanks the grid.
  Future<void> _loadActivity() async {
    try {
      final activity = await context.read<GoalProvider>().activityInRange(
          _windowLeft.subtract(const Duration(days: 3)),
          _windowLeft.add(const Duration(days: 5)));
      if (mounted) setState(() => _activity = activity);
    } catch (_) {/* keep last activity */}
  }

  void _onPageChanged(int page) {
    setState(() => _windowLeft = _leftForPage(page));
    _loadActivity();
  }

  bool get _todayVisible {
    final today = dateOnly(DateTime.now());
    return !today.isBefore(_windowLeft) &&
        !today.isAfter(_windowLeft.add(const Duration(days: 2)));
  }

  void _goToToday() {
    final today = dateOnly(DateTime.now());
    final block = (today.difference(_anchorLeft).inDays / 3).floor();
    _controller.animateToPage(_kEpochPage + block,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  String _rangeLabel(DateTime left) {
    final right = left.add(const Duration(days: 2));
    return '${DateFormat('EEE d').format(left)} – ${DateFormat('EEE d MMM').format(right)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header strip: visible 3-day range + a Today snap-back button.
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(children: [
          Expanded(
            child: Text(_rangeLabel(_windowLeft),
                style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (!_todayVisible)
            TextButton.icon(
              onPressed: _goToToday,
              icon: const Icon(Icons.today, size: 16, color: kAmber),
              label: const Text('Today', style: TextStyle(color: kAmber)),
            ),
        ]),
      ),
      Expanded(
        child: PageView.builder(
          controller: _controller,
          onPageChanged: _onPageChanged,
          itemBuilder: (_, page) => _threeDayPage(_leftForPage(page)),
        ),
      ),
    ]);
  }

  Widget _threeDayPage(DateTime left) {
    final days = [left, left.add(const Duration(days: 1)), left.add(const Duration(days: 2))];
    // LayoutBuilder sizes each column to exactly one third of the page width.
    return LayoutBuilder(builder: (context, constraints) {
      final colW = constraints.maxWidth / 3;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final d in days) SizedBox(width: colW, child: _column(d))],
      );
    });
  }

  Widget _column(DateTime day) {
    final provider = context.watch<GoalProvider>();
    final occ = provider.occurrencesOn(day);
    final act = _activity[ymd(day)];
    final isToday = dateOnly(day) == dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? kAmber.withValues(alpha: 0.07) : kCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isToday ? kAmber : kBorderDim),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => widget.onTapDay(day),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Text(DateFormat('EEE').format(day),
                    style: TextStyle(color: isToday ? kAmber : kTextDim, fontSize: 12)),
                Text('${day.day}',
                    style: TextStyle(
                        color: isToday ? kAmber : kText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          const Divider(height: 1, color: kBorderDim),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final o in occ)
                  _weekGoalChip(o.goal, o.row?.status ?? OccurrenceStatus.open, day),
                if (act != null) ...DaySummaryChip.forActivity(act),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  /// Goal chip sized for a narrow column: full width, ≥ 64dp tall.
  Widget _weekGoalChip(Goal goal, OccurrenceStatus status, DateTime day) {
    final color = occurrenceStatusColor(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => showGoalActionDialog(context, goal: goal, date: day),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: goal.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: goal.color.withValues(alpha: 0.55)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: goalPriorityColor(goal.priority), shape: BoxShape.circle)),
              const Spacer(),
              Icon(occurrenceStatusIcon(status), size: 14, color: color),
            ]),
            const SizedBox(height: 4),
            Text(goal.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: kText,
                    fontSize: 11,
                    decoration: status == OccurrenceStatus.done ? TextDecoration.lineThrough : null,
                    decorationColor: color)),
          ]),
        ),
      ),
    );
  }
}
