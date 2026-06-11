import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/index.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/colored_left_border_card.dart';
import 'calendar_month_view.dart';
import 'calendar_week_view.dart';
import 'calendar_day_view.dart';
import 'goal_create_screen.dart';
import 'goal_history_screen.dart';
import 'goal_examples.dart';

enum CalendarViewMode { day, week, month }

/// Persisted last-selected calendar view mode. Week is only the first-run
/// default; the user's choice is remembered across launches.
const String _kViewModePref = 'calendar.view_mode';

/// The Calendar / Goals tab. Hosts the Day / Week / Month views over a focused
/// date, a create-goal FAB, and (in Phase 5) the history overflow.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // First-run default is Week; overridden by the persisted choice on launch.
  CalendarViewMode _mode = CalendarViewMode.week;
  DateTime _focused = dateOnly(DateTime.now());
  Map<String, DayActivity> _activity = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final goals = context.read<GoalProvider>();
    await _loadViewMode();
    await goals.ensureLoaded();
    await _loadActivity();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kViewModePref);
    for (final m in CalendarViewMode.values) {
      if (m.name == name && mounted) {
        setState(() => _mode = m);
        return;
      }
    }
  }

  void _setMode(CalendarViewMode m) {
    setState(() => _mode = m);
    _loadActivity();
    SharedPreferences.getInstance().then((p) => p.setString(_kViewModePref, m.name));
  }

  ({DateTime from, DateTime to}) _visibleRange() {
    switch (_mode) {
      case CalendarViewMode.day:
        return (from: _focused, to: _focused);
      case CalendarViewMode.week:
        final m = mondayOf(_focused);
        return (from: m, to: m.add(const Duration(days: 6)));
      case CalendarViewMode.month:
        final first = DateTime(_focused.year, _focused.month, 1);
        final start = mondayOf(first);
        return (from: start, to: start.add(const Duration(days: 41)));
    }
  }

  Future<void> _loadActivity() async {
    final range = _visibleRange();
    final activity = await context.read<GoalProvider>().activityInRange(range.from, range.to);
    if (mounted) setState(() => _activity = activity);
  }

  Future<void> _refresh() async {
    await context.read<GoalProvider>().runSweep();
    await _loadActivity();
  }

  void _shift(int dir) {
    setState(() {
      switch (_mode) {
        case CalendarViewMode.day:
          _focused = _focused.add(Duration(days: dir));
        case CalendarViewMode.week:
          _focused = _focused.add(Duration(days: 7 * dir));
        case CalendarViewMode.month:
          _focused = DateTime(_focused.year, _focused.month + dir, 1);
      }
    });
    _loadActivity();
  }

  void _openDay(DateTime day) {
    setState(() {
      _focused = dateOnly(day);
      _mode = CalendarViewMode.day;
    });
    _loadActivity();
  }

  String get _title {
    switch (_mode) {
      case CalendarViewMode.day:
        return DateFormat('EEE, MMM d').format(_focused).toUpperCase();
      case CalendarViewMode.week:
        // The 3-day view shows its own precise range in its header strip.
        return DateFormat('MMMM yyyy').format(_focused).toUpperCase();
      case CalendarViewMode.month:
        return DateFormat('MMMM yyyy').format(_focused).toUpperCase();
    }
  }

  Future<void> _createGoal() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalCreateScreen()));
    if (mounted) await _loadActivity();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: AppText.titleM),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(LucideIcons.calendarCheck,
                size: 20, color: AppColors.textSecondary),
            onPressed: () {
              setState(() => _focused = dateOnly(DateTime.now()));
              _loadActivity();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreVertical,
                size: 18, color: AppColors.textSecondary),
            onSelected: (v) async {
              if (v == 'history') {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GoalHistoryScreen()));
                if (mounted) await _loadActivity();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'history', child: Text('History')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.calendarAmber,
        foregroundColor: AppColors.surface0,
        onPressed: _createGoal,
        child: const Icon(LucideIcons.plus),
      ),
      body: Column(children: [
        _modeBar(),
        // The 3-day Week view self-navigates (swipe) and has its own header,
        // so the parent prev/next bar is hidden in that mode.
        if (_mode != CalendarViewMode.week) _navBar(),
        if (provider.isLoaded && provider.activeGoals.isEmpty) _emptyHint(),
        Expanded(
          child: _mode == CalendarViewMode.week
              ? _body()
              : RefreshIndicator(
                  color: AppColors.calendarAmber,
                  onRefresh: _refresh,
                  child: _body()),
        ),
      ]),
    );
  }

  Widget _body() {
    switch (_mode) {
      case CalendarViewMode.day:
        // Wrap so RefreshIndicator has a scrollable; day view is already a list.
        return CalendarDayView(
          date: _focused,
          onJumpToToday: () {
            setState(() => _focused = dateOnly(DateTime.now()));
            _loadActivity();
          },
        );
      case CalendarViewMode.week:
        // Re-key on the focused date so the parent "Today" / day-tap re-centers
        // the 3-day window.
        return CalendarWeekView(
          key: ValueKey(_focused),
          initialDate: _focused,
          onTapDay: _openDay,
        );
      case CalendarViewMode.month:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: CalendarMonthView(month: _focused, activity: _activity, onTapDay: _openDay),
        );
    }
  }

  Widget _modeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.s12, Spacing.s8, Spacing.s12, Spacing.s4),
      child: Row(children: [
        for (final m in CalendarViewMode.values)
          Expanded(
            child: GestureDetector(
              onTap: () => _setMode(m),
              child: AnimatedContainer(
                duration: AppMotion.enter,
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: Spacing.s4 / 2),
                padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(
                    color: m == _mode
                        ? AppColors.calendarAmber
                        : AppColors.surface2,
                    width: m == _mode ? AppMotion.focusBorderWidth : 1,
                  ),
                  boxShadow: m == _mode
                      ? AppMotion.accentGlow(AppColors.calendarAmber)
                      : null,
                ),
                child: Text(m.name[0].toUpperCase() + m.name.substring(1),
                    style: AppText.bodyS.copyWith(
                        color: m == _mode
                            ? AppColors.calendarAmber
                            : AppColors.textSecondary)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _navBar() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
          icon: const Icon(LucideIcons.chevronLeft,
              color: AppColors.textSecondary),
          onPressed: () => _shift(-1)),
      Text(_title, style: AppText.bodyS),
      IconButton(
          icon: const Icon(LucideIcons.chevronRight,
              color: AppColors.textSecondary),
          onPressed: () => _shift(1)),
    ]);
  }

  Widget _emptyHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.s12, Spacing.s4, Spacing.s12, Spacing.s4),
      child: ColoredLeftBorderCard(
        accent: AppColors.calendarAmber,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(LucideIcons.flag,
                color: AppColors.textSecondary, size: 18),
            const SizedBox(width: Spacing.s12),
            Expanded(
              child: Text(
                  'No goals yet — plan your first one to start tracking streaks.',
                  style: AppText.bodyS),
            ),
          ]),
          const SizedBox(height: Spacing.s12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _createGoal,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.calendarAmber,
                    side: const BorderSide(
                        color: AppColors.calendarAmber, width: 1.5)),
                child: const Text('Create your first goal'),
              ),
            ),
            const SizedBox(width: Spacing.s12),
            OutlinedButton(
              onPressed: _showExamples,
              child: const Text('See examples'),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _showExamples() async {
    final examples = goalExamples(DateTime.now());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('EXAMPLE GOALS', style: AppText.caption),
            const SizedBox(height: Spacing.s4),
            Text('Tap one to pre-fill the create form.',
                style:
                    AppText.bodyM.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: Spacing.s12),
            ...examples.map((g) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(width: 14, height: 14, decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(4))),
                  title: Text(g.title, style: AppText.bodyL),
                  subtitle: Text(g.categoryLabel, style: AppText.caption),
                  trailing: const Icon(LucideIcons.plus,
                      color: AppColors.calendarAmber, size: 18),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => GoalCreateScreen(template: g)));
                    if (mounted) await _loadActivity();
                  },
                )),
          ]),
        ),
      ),
    );
  }
}
