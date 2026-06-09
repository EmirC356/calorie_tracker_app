import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';

const int kTitleMaxLen = 80;
const int kDescMaxLen = 500;

/// Shared create/edit/suggest form for a [Goal]. Drives all 13 fields and
/// builds a [Goal] handed back via [onSubmit]. Reused by GoalCreateScreen,
/// GoalEditScreen, and the squad "suggest a goal" flow (which hides the
/// squad-visible toggle — the recipient decides visibility on accept).
class GoalFormScreen extends StatefulWidget {
  final Goal? initial;
  final String appBarTitle;
  final String submitLabel;
  final bool showSquadVisible;
  final Future<void> Function(Goal goal) onSubmit;

  const GoalFormScreen({
    super.key,
    required this.onSubmit,
    this.initial,
    this.appBarTitle = 'New Goal',
    this.submitLabel = 'SAVE',
    this.showSquadVisible = true,
  });

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

enum _RecType { none, daily, weekly, monthly }

enum _EndMode { never, until, count }

enum _ReminderMode { none, before30, custom }

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _customLabel = TextEditingController();
  final _target = TextEditingController();
  final _minDur = TextEditingController(text: '20');
  final _customReminder = TextEditingController(text: '15');

  GoalCategory _category = GoalCategory.health;
  Color _color = kCatHealth;
  GoalPriority _priority = GoalPriority.medium;
  GoalType _type = GoalType.manual;
  TrackedMetric _metric = TrackedMetric.kcalTotal;
  Comparator _comparator = Comparator.lessThanOrEqual;
  GoalPeriod _period = GoalPeriod.day;

  DateTime _startDate = dateOnly(DateTime.now());
  bool _timeEnabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  _RecType _recType = _RecType.none;
  bool _weeklyCountMode = false; // false = weekday-specific, true = N/week
  final Set<int> _weekdays = {DateTime.monday};
  int _nTimes = 3;
  int _monthDay = 1;

  _EndMode _endMode = _EndMode.never;
  DateTime _until = dateOnly(DateTime.now()).add(const Duration(days: 30));
  int _count = 10;

  _ReminderMode _reminderMode = _ReminderMode.none;
  bool _morningBrief = true;
  bool _squadVisible = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    if (g != null) _hydrate(g);
  }

  void _hydrate(Goal g) {
    _title.text = g.title;
    _desc.text = g.description ?? '';
    _category = g.category;
    _customLabel.text = g.customCategoryLabel ?? '';
    _color = g.color;
    _priority = g.priority;
    _type = g.type;
    _metric = g.metric ?? TrackedMetric.kcalTotal;
    _comparator = g.comparator ?? Comparator.lessThanOrEqual;
    _period = g.period ?? GoalPeriod.day;
    if (g.target != null) _target.text = _fmtNum(g.target!);
    _minDur.text = '${g.effectiveMinDurationMin}';
    _startDate = dateOnly(g.startDate);
    if (g.timeOfDay != null) {
      _timeEnabled = true;
      _time = g.timeOfDay!;
    }
    switch (g.recurrence) {
      case RecurrenceNone():
        _recType = _RecType.none;
      case RecurrenceDaily():
        _recType = _RecType.daily;
      case RecurrenceWeekly(weekdaysMask: final m, nTimesPerWeek: final n):
        _recType = _RecType.weekly;
        if (n != null) {
          _weeklyCountMode = true;
          _nTimes = n;
        } else {
          _weeklyCountMode = false;
          _weekdays
            ..clear()
            ..addAll([
              for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                if ((m & (1 << (d - 1))) != 0) d
            ]);
        }
      case RecurrenceMonthly(dayOfMonth: final d):
        _recType = _RecType.monthly;
        _monthDay = d;
    }
    if (g.endDateDaysFromStart != null) {
      _endMode = _EndMode.until;
      _until = g.seriesEndDate!;
    }
    if (g.reminderMinutesBefore != null) {
      if (g.reminderMinutesBefore == 30) {
        _reminderMode = _ReminderMode.before30;
      } else {
        _reminderMode = _ReminderMode.custom;
        _customReminder.text = '${g.reminderMinutesBefore}';
      }
    }
    _morningBrief = g.morningBriefIncluded;
    _squadVisible = g.squadVisible;
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    for (final c in [_title, _desc, _customLabel, _target, _minDur, _customReminder]) {
      c.dispose();
    }
    super.dispose();
  }

  Recurrence _buildRecurrence() {
    switch (_recType) {
      case _RecType.none:
        return const RecurrenceNone();
      case _RecType.daily:
        return const RecurrenceDaily();
      case _RecType.weekly:
        if (_weeklyCountMode) {
          return RecurrenceWeekly(nTimesPerWeek: _nTimes.clamp(1, 7));
        }
        var mask = 0;
        for (final d in _weekdays) {
          mask |= 1 << (d - 1);
        }
        return RecurrenceWeekly(weekdaysMask: mask == 0 ? kMon : mask);
      case _RecType.monthly:
        return RecurrenceMonthly(dayOfMonth: _monthDay);
    }
  }

  int? _buildEndDays(Recurrence recurrence) {
    switch (_endMode) {
      case _EndMode.never:
        return null;
      case _EndMode.until:
        final days = dateOnly(_until).difference(dateOnly(_startDate)).inDays;
        return days < 0 ? 0 : days;
      case _EndMode.count:
        if (_recType == _RecType.none) return 0;
        // Find the date of the Nth occurrence via the engine.
        final draft = _draftForEngine(recurrence);
        const engine = RecurrenceEngine();
        final dates = engine.occurrencesInRange(
            draft, _startDate, _startDate.add(const Duration(days: 366 * 5)));
        if (dates.isEmpty) return 0;
        final nth = dates[(_count.clamp(1, dates.length)) - 1];
        return dateOnly(nth).difference(dateOnly(_startDate)).inDays;
    }
  }

  Goal _draftForEngine(Recurrence recurrence) => Goal(
        title: 't',
        category: _category,
        color: _color,
        startDate: _startDate,
        recurrence: recurrence,
        createdAt: DateTime.now(),
      );

  int? _buildReminder() {
    if (!_timeEnabled) return null;
    switch (_reminderMode) {
      case _ReminderMode.none:
        return null;
      case _ReminderMode.before30:
        return 30;
      case _ReminderMode.custom:
        return int.tryParse(_customReminder.text.trim());
    }
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'A title is required';
    if (_type == GoalType.tracked) {
      final t = double.tryParse(_target.text.trim());
      if (t == null) return 'Enter a numeric target for the tracked metric';
    }
    if (_recType == _RecType.weekly && !_weeklyCountMode && _weekdays.isEmpty) {
      return 'Pick at least one weekday';
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final recurrence = _buildRecurrence();
    final goal = Goal(
      id: widget.initial?.id,
      title: _title.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      category: _category,
      customCategoryLabel: _category == GoalCategory.custom
          ? (_customLabel.text.trim().isEmpty ? null : _customLabel.text.trim())
          : null,
      color: _color,
      priority: _priority,
      type: _type,
      metric: _type == GoalType.tracked ? _metric : null,
      comparator: _type == GoalType.tracked ? _comparator : null,
      target: _type == GoalType.tracked ? double.tryParse(_target.text.trim()) : null,
      period: _type == GoalType.tracked ? _period : null,
      minDurationMin: _type == GoalType.tracked && _metric == TrackedMetric.exerciseSessionCount
          ? (int.tryParse(_minDur.text.trim()) ?? 20)
          : null,
      startDate: _startDate,
      timeOfDay: _timeEnabled ? _time : null,
      recurrence: recurrence,
      endDateDaysFromStart: _buildEndDays(recurrence),
      squadVisible: widget.showSquadVisible ? _squadVisible : false,
      reminderMinutesBefore: _buildReminder(),
      morningBriefIncluded: _morningBrief,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      archived: widget.initial?.archived ?? false,
    );
    setState(() => _saving = true);
    try {
      await widget.onSubmit(goal);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle.toUpperCase()),
        titleTextStyle: const TextStyle(
            color: kAmber, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        iconTheme: const IconThemeData(color: kAmber),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _field('Title', TextField(
          controller: _title,
          maxLength: kTitleMaxLen,
          style: const TextStyle(color: kText),
          decoration: const InputDecoration(hintText: 'e.g. Stay under 2200 kcal'),
        )),
        _field('Description (optional)', TextField(
          controller: _desc,
          maxLength: kDescMaxLen,
          maxLines: 2,
          style: const TextStyle(color: kText),
          decoration: const InputDecoration(hintText: 'Notes for yourself'),
        )),
        _categorySection(),
        _colorSection(),
        _label('Priority'),
        _segmented<GoalPriority>(GoalPriority.values, _priority,
            (p) => p.name[0].toUpperCase() + p.name.substring(1), (p) => setState(() => _priority = p)),
        const SizedBox(height: 16),
        _label('Goal type'),
        _segmented<GoalType>(GoalType.values, _type,
            (t) => t.name[0].toUpperCase() + t.name.substring(1), (t) => setState(() => _type = t)),
        if (_type == GoalType.tracked) _trackedSection(),
        const SizedBox(height: 16),
        _scheduleSection(),
        const SizedBox(height: 8),
        _recurrenceSection(),
        const SizedBox(height: 8),
        _endSection(),
        const SizedBox(height: 8),
        _reminderSection(),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kAmber,
          title: const Text('Include in morning brief', style: TextStyle(color: kText, fontSize: 14)),
          subtitle: const Text('Show this goal in your 8:00 daily summary',
              style: TextStyle(color: kTextDim, fontSize: 12)),
          value: _morningBrief,
          onChanged: (v) => setState(() => _morningBrief = v),
        ),
        if (widget.showSquadVisible)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: kAmber,
            title: Row(children: [
              const Text('Squad-visible', style: TextStyle(color: kText, fontSize: 14)),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Squadmates you share a squad with will see this goal\'s '
                    'title, category and status on their Today view — not your '
                    'private notes.',
                child: Icon(Icons.info_outline, size: 15, color: kTextDim),
              ),
            ]),
            value: _squadVisible,
            onChanged: (v) => setState(() => _squadVisible = v),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: kAmber, foregroundColor: kBg,
              padding: const EdgeInsets.symmetric(vertical: 14)),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kBg))
              : Text(widget.submitLabel, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ─── Sections ────────────────────────────────────────────────────────────────

  Widget _categorySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Category'),
      DropdownButtonFormField<GoalCategory>(
        initialValue: _category,
        dropdownColor: kCard,
        style: const TextStyle(color: kText, fontSize: 14),
        items: GoalCategory.values
            .map((c) => DropdownMenuItem(
                value: c, child: Text(c.name[0].toUpperCase() + c.name.substring(1))))
            .toList(),
        onChanged: (c) {
          if (c == null) return;
          setState(() {
            _category = c;
            // Snap color to the category default unless the user picked custom.
            if (c != GoalCategory.custom) _color = goalCategoryColor(c.name);
          });
        },
      ),
      if (_category == GoalCategory.custom)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: _customLabel,
            maxLength: 24,
            style: const TextStyle(color: kText),
            decoration: const InputDecoration(hintText: 'Custom category label'),
          ),
        ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _colorSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Color'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final c in kGoalPalette)
          GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                    color: _color.toARGB32() == c.toARGB32() ? kWhite : Colors.transparent,
                    width: 2),
              ),
              child: _color.toARGB32() == c.toARGB32()
                  ? const Icon(Icons.check, size: 16, color: kBg)
                  : null,
            ),
          ),
      ]),
      const SizedBox(height: 16),
    ]);
  }

  Widget _trackedSection() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: neonBox(kAmber),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Metric'),
        DropdownButtonFormField<TrackedMetric>(
          initialValue: _metric,
          dropdownColor: kCard,
          style: const TextStyle(color: kText, fontSize: 14),
          items: TrackedMetric.values
              .map((m) => DropdownMenuItem(value: m, child: Text(_metricLabel(m))))
              .toList(),
          onChanged: (m) => setState(() => _metric = m ?? _metric),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Comparator'),
              _segmented<Comparator>(Comparator.values, _comparator,
                  (c) => c == Comparator.lessThanOrEqual ? '≤' : '≥',
                  (c) => setState(() => _comparator = c)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Target'),
              TextField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: kText),
                decoration: const InputDecoration(hintText: 'e.g. 2200'),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        _label('Period'),
        _segmented<GoalPeriod>(GoalPeriod.values, _period,
            (p) => p.name[0].toUpperCase() + p.name.substring(1), (p) => setState(() => _period = p)),
        if (_metric == TrackedMetric.exerciseSessionCount) ...[
          const SizedBox(height: 10),
          _label('Min session duration (min)'),
          TextField(
            controller: _minDur,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: kText),
            decoration: const InputDecoration(hintText: '20'),
          ),
        ],
      ]),
    );
  }

  Widget _scheduleSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Start date'),
      _tappableValue(DateFormat('EEE, MMM d, yyyy').format(_startDate), Icons.calendar_today, () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _startDate = dateOnly(picked));
      }),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: kAmber,
        title: const Text('Set a time', style: TextStyle(color: kText, fontSize: 14)),
        value: _timeEnabled,
        onChanged: (v) => setState(() => _timeEnabled = v),
      ),
      if (_timeEnabled)
        _tappableValue(_time.format(context), Icons.access_time, () async {
          final picked = await showTimePicker(context: context, initialTime: _time);
          if (picked != null) setState(() => _time = picked);
        }),
    ]);
  }

  Widget _recurrenceSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Recurrence'),
      _segmented<_RecType>(_RecType.values, _recType,
          (r) => r.name[0].toUpperCase() + r.name.substring(1), (r) => setState(() => _recType = r)),
      if (_recType == _RecType.weekly) ...[
        const SizedBox(height: 10),
        Row(children: [
          _miniToggle('Specific days', !_weeklyCountMode, () => setState(() => _weeklyCountMode = false)),
          const SizedBox(width: 8),
          _miniToggle('N / week', _weeklyCountMode, () => setState(() => _weeklyCountMode = true)),
        ]),
        const SizedBox(height: 10),
        if (!_weeklyCountMode)
          Wrap(spacing: 6, children: [
            for (var d = DateTime.monday; d <= DateTime.sunday; d++)
              _dayToggle(d),
          ])
        else
          _stepper('Times per week', _nTimes, 1, 7, (v) => setState(() => _nTimes = v)),
      ],
      if (_recType == _RecType.monthly) ...[
        const SizedBox(height: 10),
        _stepper('Day of month (1–28)', _monthDay, 1, 28, (v) => setState(() => _monthDay = v)),
      ],
    ]);
  }

  Widget _endSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Series end'),
      _segmented<_EndMode>(_EndMode.values, _endMode, (m) {
        switch (m) {
          case _EndMode.never:
            return 'Never';
          case _EndMode.until:
            return 'Until date';
          case _EndMode.count:
            return 'For N';
        }
      }, (m) => setState(() => _endMode = m)),
      if (_endMode == _EndMode.until) ...[
        const SizedBox(height: 8),
        _tappableValue(DateFormat('MMM d, yyyy').format(_until), Icons.event, () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _until.isBefore(_startDate) ? _startDate : _until,
            firstDate: _startDate,
            lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => _until = dateOnly(picked));
        }),
      ],
      if (_endMode == _EndMode.count) ...[
        const SizedBox(height: 8),
        _stepper('Number of occurrences', _count, 1, 365, (v) => setState(() => _count = v)),
      ],
    ]);
  }

  Widget _reminderSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Reminder'),
      if (!_timeEnabled)
        const Text('Set a time above to enable reminders',
            style: TextStyle(color: kTextDim, fontSize: 12))
      else ...[
        _segmented<_ReminderMode>(_ReminderMode.values, _reminderMode, (m) {
          switch (m) {
            case _ReminderMode.none:
              return 'None';
            case _ReminderMode.before30:
              return '30 min before';
            case _ReminderMode.custom:
              return 'Custom';
          }
        }, (m) => setState(() => _reminderMode = m)),
        if (_reminderMode == _ReminderMode.custom) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customReminder,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: kText),
            decoration: const InputDecoration(hintText: 'Minutes before', suffixText: 'min'),
          ),
        ],
      ],
    ]);
  }

  // ─── Small UI helpers ────────────────────────────────────────────────────────

  Widget _field(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_label(label), child, const SizedBox(height: 6)],
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(t, style: neonLabel(kAmber, size: 12)),
      );

  Widget _segmented<T>(List<T> values, T current, String Function(T) label, ValueChanged<T> onChanged) {
    return Row(
      children: [
        for (final v in values)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == current ? kAmber.withValues(alpha: 0.2) : kCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: v == current ? kAmber : kBorderDim),
                ),
                child: Text(label(v),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: v == current ? kAmber : kTextDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _miniToggle(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? kAmber.withValues(alpha: 0.2) : kCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: active ? kAmber : kBorderDim),
          ),
          child: Text(label, style: TextStyle(color: active ? kAmber : kTextDim, fontSize: 12)),
        ),
      );

  Widget _dayToggle(int weekday) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final active = _weekdays.contains(weekday);
    return GestureDetector(
      onTap: () => setState(() {
        if (active) {
          _weekdays.remove(weekday);
        } else {
          _weekdays.add(weekday);
        }
      }),
      child: Container(
        width: 34, height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? kAmber.withValues(alpha: 0.25) : kCard,
          shape: BoxShape.circle,
          border: Border.all(color: active ? kAmber : kBorderDim),
        ),
        child: Text(labels[weekday - 1],
            style: TextStyle(color: active ? kAmber : kTextDim, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) => Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: kText, fontSize: 13))),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: kAmber),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: kAmber),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ]);

  Widget _tappableValue(String text, IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: neonBox(kAmber),
          child: Row(children: [
            Icon(icon, size: 18, color: kAmber),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(color: kText, fontSize: 14)),
          ]),
        ),
      );

  static String _metricLabel(TrackedMetric m) {
    switch (m) {
      case TrackedMetric.kcalTotal:
        return 'Calories (kcal)';
      case TrackedMetric.proteinG:
        return 'Protein (g)';
      case TrackedMetric.exerciseMinutes:
        return 'Exercise minutes';
      case TrackedMetric.exerciseSessionCount:
        return 'Exercise sessions';
      case TrackedMetric.weightDeltaKg:
        return 'Weight change (kg)';
      case TrackedMetric.waterMl:
        return 'Water (ml)';
    }
  }
}
