import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
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
        padding: const EdgeInsets.fromLTRB(
            Spacing.s16, Spacing.s8, Spacing.s8, Spacing.s8),
        child: Row(children: [
          Expanded(
            child: Text(_rangeLabel(_windowLeft),
                style: AppText.tabular(AppText.titleM)),
          ),
          // Always visible; greyed out + disabled while today is in view.
          TextButton.icon(
            onPressed: _todayVisible ? null : _goToToday,
            icon: Icon(LucideIcons.calendarCheck,
                size: 16,
                color: _todayVisible
                    ? AppColors.textTertiary
                    : AppColors.calendarAmber),
            label: Text('Today',
                style: AppText.bodyS.copyWith(
                    color: _todayVisible
                        ? AppColors.textTertiary
                        : AppColors.calendarAmber)),
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
      // Columns stagger in left-to-right on page build (60ms apart).
      return AnimationLimiter(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: AnimationConfiguration.toStaggeredList(
            duration: AppMotion.enter,
            delay: AppMotion.staggerStep,
            childAnimationBuilder: (w) => SlideAnimation(
              verticalOffset: 24,
              curve: Curves.easeOutCubic,
              child: FadeInAnimation(child: w),
            ),
            children: [
              for (final d in days) SizedBox(width: colW, child: _column(d))
            ],
          ),
        ),
      );
    });
  }

  Widget _column(DateTime day) {
    final provider = context.watch<GoalProvider>();
    final occ = provider.occurrencesOn(day);
    final act = _activity[ymd(day)];
    final isToday = dateOnly(day) == dateOnly(DateTime.now());

    final empty = occ.isEmpty && act == null;

    // TODO(ui): clarify the "now" line — columns are stacked lists with no
    // hour axis, so a time-positioned line needs a layout change (out of
    // scope for the visual-only pass).
    return Padding(
      padding: const EdgeInsets.all(Spacing.s4 / 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Day header: caption weekday over a displayM tabular day-of-month;
        // today carries a 2px calendarAmber underline (design/system.md).
        InkWell(
          onTap: () => widget.onTapDay(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
            child: Column(children: [
              Text(DateFormat('EEE').format(day).toUpperCase(),
                  style: AppText.caption.copyWith(
                      color: isToday
                          ? AppColors.calendarAmber
                          : AppColors.textSecondary)),
              Text('${day.day}', style: AppText.tabular(AppText.displayM)),
              const SizedBox(height: Spacing.s4),
              Container(
                width: Spacing.s24,
                height: 2,
                color: isToday
                    ? AppColors.calendarAmber
                    : Colors.transparent,
              ),
            ]),
          ),
        ),
        const Divider(height: 1, color: AppColors.surface2),
        Expanded(
          child: empty
              // Empty days: a single muted dot, no text.
              ? Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.textTertiary),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(Spacing.s4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final o in occ)
                          _weekGoalChip(o.goal,
                              o.row?.status ?? OccurrenceStatus.open, day),
                        if (act != null) ...DaySummaryChip.forActivity(act),
                      ]),
                ),
        ),
      ]),
    );
  }

  /// Goal capsule sized for a narrow column: surface1 with a 4px left border
  /// in the goal's category color, ≥ 64dp tall.
  Widget _weekGoalChip(Goal goal, OccurrenceStatus status, DateTime day) {
    final color = occurrenceStatusColor(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s4),
      child: InkWell(
        onTap: () => showGoalActionDialog(context, goal: goal, date: day),
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
          foregroundDecoration: BoxDecoration(
            border: Border(left: BorderSide(color: goal.color, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(
              Spacing.s12, Spacing.s8, Spacing.s8, Spacing.s8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: goalPriorityColor(goal.priority), shape: BoxShape.circle)),
              const Spacer(),
              Icon(occurrenceStatusIcon(status), size: 14, color: color),
            ]),
            const SizedBox(height: Spacing.s4),
            Text(goal.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyS.copyWith(
                    fontSize: 11,
                    decoration: status == OccurrenceStatus.done ? TextDecoration.lineThrough : null,
                    decorationColor: color)),
          ]),
        ),
      ),
    );
  }
}
