import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import 'calendar_month_view.dart';
import 'calendar_week_view.dart';
import 'calendar_day_view.dart';
import 'goal_create_screen.dart';

enum CalendarViewMode { day, week, month }

/// The Calendar / Goals tab. Hosts the Day / Week / Month views over a focused
/// date, a create-goal FAB, and (in Phase 5) the history overflow.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarViewMode _mode = CalendarViewMode.month;
  DateTime _focused = dateOnly(DateTime.now());
  Map<String, DayActivity> _activity = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await context.read<GoalProvider>().ensureLoaded();
    await _loadActivity();
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
        final m = mondayOf(_focused);
        final s = m.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(m)} – ${DateFormat('MMM d').format(s)}'.toUpperCase();
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
        title: Text(_title),
        titleTextStyle: const TextStyle(
            color: kAmber, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        iconTheme: const IconThemeData(color: kAmber),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() => _focused = dateOnly(DateTime.now()));
              _loadActivity();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAmber,
        foregroundColor: kBg,
        onPressed: _createGoal,
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        _modeBar(),
        _navBar(),
        if (provider.isLoaded && provider.activeGoals.isEmpty) _emptyHint(),
        Expanded(
          child: RefreshIndicator(
            color: kAmber,
            onRefresh: _refresh,
            child: _body(),
          ),
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
        return ListView(children: [
          SizedBox(
            height: 420,
            child: CalendarWeekView(focused: _focused, activity: _activity, onTapDay: _openDay),
          ),
        ]);
      case CalendarViewMode.month:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: CalendarMonthView(month: _focused, activity: _activity, onTapDay: _openDay),
        );
    }
  }

  Widget _modeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        for (final m in CalendarViewMode.values)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _mode = m);
                _loadActivity();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: m == _mode ? kAmber.withValues(alpha: 0.2) : kCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: m == _mode ? kAmber : kBorderDim),
                ),
                child: Text(m.name[0].toUpperCase() + m.name.substring(1),
                    style: TextStyle(
                        color: m == _mode ? kAmber : kTextDim,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _navBar() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(icon: const Icon(Icons.chevron_left, color: kAmber), onPressed: () => _shift(-1)),
      Text(_title, style: const TextStyle(color: kText, fontSize: 13)),
      IconButton(icon: const Icon(Icons.chevron_right, color: kAmber), onPressed: () => _shift(1)),
    ]);
  }

  Widget _emptyHint() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: neonBox(kAmber),
      child: Row(children: [
        Icon(Icons.flag_outlined, color: kAmber.withValues(alpha: 0.9)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('No goals yet. Tap + to create your first goal.',
              style: TextStyle(color: kText, fontSize: 13)),
        ),
      ]),
    );
  }
}
