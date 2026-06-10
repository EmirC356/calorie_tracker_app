import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: kAmber),
            color: kCard,
            onSelected: (v) async {
              if (v == 'history') {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GoalHistoryScreen()));
                if (mounted) await _loadActivity();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'history', child: Text('History', style: TextStyle(color: kText))),
            ],
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
        // The 3-day Week view self-navigates (swipe) and has its own header,
        // so the parent prev/next bar is hidden in that mode.
        if (_mode != CalendarViewMode.week) _navBar(),
        if (provider.isLoaded && provider.activeGoals.isEmpty) _emptyHint(),
        Expanded(
          child: _mode == CalendarViewMode.week
              ? _body()
              : RefreshIndicator(color: kAmber, onRefresh: _refresh, child: _body()),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        for (final m in CalendarViewMode.values)
          Expanded(
            child: GestureDetector(
              onTap: () => _setMode(m),
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
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kAmber),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.flag_outlined, color: kAmber.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('No goals yet — plan your first one to start tracking streaks.',
                style: TextStyle(color: kText, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _createGoal,
              style: ElevatedButton.styleFrom(backgroundColor: kAmber, foregroundColor: kBg),
              child: const Text('Create your first goal'),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: _showExamples,
            style: OutlinedButton.styleFrom(foregroundColor: kAmber, side: const BorderSide(color: kAmber)),
            child: const Text('See examples'),
          ),
        ]),
      ]),
    );
  }

  Future<void> _showExamples() async {
    final examples = goalExamples(DateTime.now());
    await showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kAmber, width: 1),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('EXAMPLE GOALS', style: neonLabel(kAmber, size: 13)),
            const SizedBox(height: 4),
            const Text('Tap one to pre-fill the create form.', style: TextStyle(color: kTextDim, fontSize: 12)),
            const SizedBox(height: 12),
            ...examples.map((g) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(width: 14, height: 14, decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(4))),
                  title: Text(g.title, style: const TextStyle(color: kText, fontSize: 14)),
                  subtitle: Text(g.categoryLabel, style: const TextStyle(color: kTextDim, fontSize: 11)),
                  trailing: const Icon(Icons.add, color: kAmber, size: 18),
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
