import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/calendar/calendar_status.dart';
import '../../widgets/calendar/goal_action_dialog.dart';
import '../../widgets/ui/ui.dart';

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
      appBar: AppBar(title: const Text('Goal History')),
      body: _loading
          ? ListView(padding: const EdgeInsets.all(Spacing.s16), children: const [
              ShimmerPlaceholder.card(height: 160),
              SizedBox(height: Spacing.s12),
              ShimmerPlaceholder.card(height: 64),
              SizedBox(height: Spacing.s12),
              ShimmerPlaceholder.card(height: 64),
              SizedBox(height: Spacing.s12),
              ShimmerPlaceholder.card(height: 64),
            ])
          : ListView(padding: const EdgeInsets.all(Spacing.s16), children: [
              _filters(categories),
              const SizedBox(height: Spacing.s16),
              GoalHistoryBody(
                entries: filtered,
                onTap: (e) async {
                  await showGoalActionDialog(context, goal: e.goal, date: e.date);
                  await _load();
                },
              ),
              const SizedBox(height: Spacing.s24),
            ]),
    );
  }

  Widget _filters(List<String> categories) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: _pickRange,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s16, vertical: Spacing.s12),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(color: AppColors.surface2),
          ),
          child: Row(children: [
            const Icon(LucideIcons.calendarDays,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: Spacing.s8),
            Text(
                '${DateFormat('MMM d').format(_from)} – ${DateFormat('MMM d, yyyy').format(_to)}',
                style: AppText.tabular(AppText.bodyM)),
          ]),
        ),
      ),
      const SizedBox(height: Spacing.s12),
      Wrap(spacing: Spacing.s8, runSpacing: Spacing.s8, children: [
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
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: AppColors.surface2),
      ),
      child: DropdownButton<T>(
        value: value,
        dropdownColor: AppColors.surface3,
        underline: const SizedBox.shrink(),
        style: AppText.bodyS,
        icon: const Icon(LucideIcons.chevronDown,
            size: 16, color: AppColors.textSecondary),
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
      const SizedBox(height: Spacing.s16),
      Text('OCCURRENCES (${entries.length})', style: AppText.caption),
      const SizedBox(height: Spacing.s8),
      if (entries.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.s24),
          child: Center(
              child: Text('No occurrences match these filters',
                  style: AppText.bodyM
                      .copyWith(color: AppColors.textTertiary))),
        )
      else
        ...entries.map(_row),
    ]);
  }

  Widget _statsCard() {
    final stats = categorySuccessRates(entries);
    if (stats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Spacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
        child: Text('No data in this range',
            style: AppText.bodyM.copyWith(color: AppColors.textTertiary)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(Spacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SUCCESS RATE BY CATEGORY', style: AppText.caption),
        const SizedBox(height: Spacing.s12),
        ...stats.entries.map((e) {
          final s = e.value;
          final rate = s.successRate;
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.s12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.key, style: AppText.bodyM),
                Text(
                    '${(rate * 100).toStringAsFixed(0)}%  (${s.done}/${s.done + s.failed})',
                    style: AppText.tabular(AppText.bodyS
                        .copyWith(color: AppColors.textSecondary))),
              ]),
              const SizedBox(height: Spacing.s4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 8,
                  backgroundColor: AppColors.surface2,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.statusHit),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // TODO(ui): clarify — spec calls for StatusPill on status badges, but the
  // goal_history widget test pins the Material status glyphs via
  // occurrenceStatusIcon and test/ is off-limits; keeping the retoned icon.
  Widget _row(GoalHistoryEntry e) {
    final color = occurrenceStatusColor(e.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s8),
      child: ColoredLeftBorderCard(
        accent: e.goal.color,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s12, vertical: Spacing.s12),
        onTap: () => onTap(e),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                    child: Text(e.goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyM
                            .copyWith(fontWeight: FontWeight.w600))),
                if (e.edited)
                  Padding(
                    padding: const EdgeInsets.only(left: Spacing.s8),
                    child: Text('edited',
                        style: AppText.caption
                            .copyWith(color: AppColors.textTertiary)),
                  ),
              ]),
              const SizedBox(height: 2),
              Text('${e.categoryLabel} · ${DateFormat('EEE, MMM d').format(e.date)}',
                  style:
                      AppText.bodyS.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(width: Spacing.s8),
          Icon(occurrenceStatusIcon(e.status), color: color, size: 18),
        ]),
      ),
    );
  }
}
