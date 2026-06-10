import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/calendar/calendar_status.dart';
import '../../widgets/calendar/goal_action_dialog.dart';

/// Goal history: a filterable list of recorded occurrences plus a per-category
/// success-rate card. Tapping a row reopens the detail sheet so a past outcome
/// can be retroactively overridden.
class GoalHistoryScreen extends StatefulWidget {
  const GoalHistoryScreen({super.key});

  @override
  State<GoalHistoryScreen> createState() => _GoalHistoryScreenState();
}

class _GoalHistoryScreenState extends State<GoalHistoryScreen> {
  late DateTime _from;
  late DateTime _to;
  OccurrenceStatus? _statusFilter; // null = all
  String? _categoryFilter; // null = all
  GoalType? _typeFilter; // null = all

  List<GoalHistoryEntry> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _to = dateOnly(DateTime.now());
    _from = _to.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await context.read<GoalProvider>().historyInRange(_from, _to);
    if (mounted) {
      setState(() {
        _all = entries;
        _loading = false;
      });
    }
  }

  List<GoalHistoryEntry> get _filtered => _all.where((e) {
        if (_statusFilter != null && e.status != _statusFilter) return false;
        if (_categoryFilter != null && e.categoryLabel != _categoryFilter) return false;
        if (_typeFilter != null && e.goal.type != _typeFilter) return false;
        return true;
      }).toList();

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = dateOnly(picked.start);
        _to = dateOnly(picked.end);
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final categories = {for (final e in _all) e.categoryLabel}.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: const Text('GOAL HISTORY'),
        titleTextStyle: const TextStyle(
            color: kAmber, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        iconTheme: const IconThemeData(color: kAmber),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAmber))
          : ListView(padding: const EdgeInsets.all(16), children: [
              _filters(categories),
              const SizedBox(height: 16),
              GoalHistoryBody(
                entries: filtered,
                onTap: (e) async {
                  await showGoalActionDialog(context, goal: e.goal, date: e.date);
                  await _load();
                },
              ),
              const SizedBox(height: 24),
            ]),
    );
  }

  Widget _filters(List<String> categories) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: _pickRange,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: neonBox(kAmber),
          child: Row(children: [
            const Icon(Icons.date_range, size: 18, color: kAmber),
            const SizedBox(width: 10),
            Text('${DateFormat('MMM d').format(_from)} – ${DateFormat('MMM d, yyyy').format(_to)}',
                style: const TextStyle(color: kText, fontSize: 14)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 8, children: [
        _dropdown<OccurrenceStatus?>(
          'Status',
          _statusFilter,
          [null, ...OccurrenceStatus.values],
          (s) => s == null ? 'All' : occurrenceStatusLabel(s),
          (s) => setState(() => _statusFilter = s),
        ),
        _dropdown<String?>(
          'Category',
          _categoryFilter,
          [null, ...categories],
          (c) => c ?? 'All',
          (c) => setState(() => _categoryFilter = c),
        ),
        _dropdown<GoalType?>(
          'Type',
          _typeFilter,
          [null, ...GoalType.values],
          (t) => t == null ? 'All' : (t.name[0].toUpperCase() + t.name.substring(1)),
          (t) => setState(() => _typeFilter = t),
        ),
      ]),
    ]);
  }

  Widget _dropdown<T>(String label, T value, List<T> items, String Function(T) toLabel,
      ValueChanged<T> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorderDim),
      ),
      child: DropdownButton<T>(
        value: value,
        dropdownColor: kCard,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: kText, fontSize: 13),
        icon: const Icon(Icons.arrow_drop_down, color: kAmber),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text('$label: ${toLabel(i)}')))
            .toList(),
        onChanged: (v) => onChanged(v as T),
      ),
    );
  }
}

/// The success-rate card + occurrence list for a fixed set of entries. Pure
/// (no IO), so it renders synchronously and is straightforward to widget-test.
class GoalHistoryBody extends StatelessWidget {
  final List<GoalHistoryEntry> entries;
  final void Function(GoalHistoryEntry entry) onTap;

  const GoalHistoryBody({super.key, required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _statsCard(),
      const SizedBox(height: 16),
      Text('OCCURRENCES (${entries.length})', style: neonLabel(kAmber, size: 13)),
      const SizedBox(height: 8),
      if (entries.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No occurrences match these filters',
              style: TextStyle(color: kTextDim))),
        )
      else
        ...entries.map(_row),
    ]);
  }

  Widget _statsCard() {
    final stats = categorySuccessRates(entries);
    if (stats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: neonBox(kAmber),
        child: const Text('No data in this range', style: TextStyle(color: kTextDim)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: neonBox(kAmber),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SUCCESS RATE BY CATEGORY', style: neonLabel(kAmber, size: 12)),
        const SizedBox(height: 12),
        ...stats.entries.map((e) {
          final s = e.value;
          final rate = s.successRate;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.key, style: const TextStyle(color: kText, fontSize: 13)),
                Text('${(rate * 100).toStringAsFixed(0)}%  (${s.done}/${s.done + s.failed})',
                    style: const TextStyle(color: kTextDim, fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 8,
                  backgroundColor: kBg,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CC38A)),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _row(GoalHistoryEntry e) {
    final color = occurrenceStatusColor(e.status);
    return InkWell(
      onTap: () => onTap(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorderDim),
        ),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: e.goal.color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(e.goal.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600))),
                if (e.edited)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text('edited', style: TextStyle(color: kTextDim, fontSize: 10, fontStyle: FontStyle.italic)),
                  ),
              ]),
              Text('${e.categoryLabel} · ${DateFormat('EEE, MMM d').format(e.date)}',
                  style: const TextStyle(color: kTextDim, fontSize: 11)),
            ]),
          ),
          Icon(occurrenceStatusIcon(e.status), color: color, size: 18),
        ]),
      ),
    );
  }
}
