import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/index.dart';
import '../../services/prefs.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart'
    show kCatHealth, kCatStudy, kCatHome, kCatPersonal, kGoalPalette, goalCategoryColor;
import '../../widgets/ui/shimmer_placeholder.dart';

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
  // Create-form default is ON (the suggest flow hides this toggle; edit/accept
  // forms hydrate the goal's own value, so this only affects fresh creates).
  bool _squadVisible = true;

  // Advanced (collapsible) section, hidden by default.
  bool _advanced = false;

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

  /// One-time explainer the first time a user makes any goal squad-visible.
  Future<void> _maybeShowPrivacyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kSquadVisiblePrivacyShownPref) == true) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Squad-visible goals'),
        content: const Text(
            "Goals you mark visible show up on your squadmates' Today view with "
            "their title, category and status — never your private notes."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
    await prefs.setBool(kSquadVisiblePrivacyShownPref, true);
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
    // Calendar room: inputs focus in calendarAmber (the app-level theme
    // defaults to the Health accent).
    final theme = Theme.of(context);
    final amberInputs = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          borderSide: const BorderSide(
              color: AppColors.calendarAmber,
              width: AppMotion.focusBorderWidth),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle)),
      body: Theme(
        data: amberInputs,
        child: ListView(padding: const EdgeInsets.all(Spacing.s16), children: [
          // ── Simple zone: exactly title, color, recurrence ──────────────────────
          _field('Title', TextField(
            controller: _title,
            maxLength: kTitleMaxLen,
            decoration: const InputDecoration(hintText: 'e.g. Stay under 2200 kcal'),
          )),
          _colorSection(),
          _recurrenceSection(),
          const SizedBox(height: Spacing.s8),
          _startDateField(),
          // ── Advanced toggle (chevron, anchored bottom-right) ───────────────────
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              onTap: () => setState(() => _advanced = !_advanced),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.s8, vertical: Spacing.s8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_advanced ? 'Fewer options' : 'More options',
                      style: AppText.bodyS
                          .copyWith(color: AppColors.calendarAmber)),
                  const SizedBox(width: Spacing.s4),
                  AnimatedRotation(
                    turns: _advanced ? 0.5 : 0.0,
                    duration: AppMotion.enter,
                    // Overshoot feel for the chevron flip (spring-adjacent;
                    // never easeInOut per the canon).
                    curve: Curves.easeOutBack,
                    child: const Icon(LucideIcons.chevronDown,
                        color: AppColors.calendarAmber, size: 18),
                  ),
                ]),
              ),
            ),
          ),
          // ── Advanced zone (collapsible) ────────────────────────────────────────
          AnimatedSize(
            duration: AppMotion.enter,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _advanced ? _advancedSection() : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: Spacing.s20),
          OutlinedButton(
            onPressed: _saving ? null : _save,
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.calendarAmber,
                side: const BorderSide(
                    color: AppColors.calendarAmber, width: 1.5)),
            child: _saving
                ? const ShimmerPlaceholder.line(width: 96)
                : Text(widget.submitLabel),
          ),
          const SizedBox(height: Spacing.s24),
        ]),
      ),
    );
  }

  /// The collapsible "advanced" fields, defaulted when left untouched.
  Widget _advancedSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _field('Description (optional)', TextField(
        controller: _desc,
        maxLength: kDescMaxLen,
        maxLines: 2,
        decoration: const InputDecoration(hintText: 'Notes for yourself'),
      )),
      _categorySection(),
      _label('Priority'),
      _segmented<GoalPriority>(GoalPriority.values, _priority,
          (p) => p.name[0].toUpperCase() + p.name.substring(1), (p) => setState(() => _priority = p)),
      const SizedBox(height: Spacing.s16),
      _label('Goal type'),
      _segmented<GoalType>(GoalType.values, _type,
          (t) => t.name[0].toUpperCase() + t.name.substring(1), (t) => setState(() => _type = t)),
      if (_type == GoalType.tracked) _trackedSection(),
      const SizedBox(height: Spacing.s16),
      _timeSection(),
      const SizedBox(height: Spacing.s8),
      _endSection(),
      const SizedBox(height: Spacing.s8),
      _reminderSection(),
      const SizedBox(height: Spacing.s8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.calendarAmber,
        title: Text('Include in morning brief', style: AppText.bodyL),
        subtitle: Text('Show this goal in your 8:00 daily summary',
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary)),
        value: _morningBrief,
        onChanged: (v) => setState(() => _morningBrief = v),
      ),
      if (widget.showSquadVisible)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.calendarAmber,
          title: Row(children: [
            Text('Squad-visible', style: AppText.bodyL),
            const SizedBox(width: Spacing.s8),
            const Tooltip(
              message: 'Squadmates you share a squad with will see this goal\'s '
                  'title, category and status on their Today view — not your '
                  'private notes.',
              child: Icon(LucideIcons.info,
                  size: 15, color: AppColors.textSecondary),
            ),
          ]),
          value: _squadVisible,
          onChanged: (v) async {
            setState(() => _squadVisible = v);
            if (v) await _maybeShowPrivacyDialog();
          },
        ),
    ]);
  }

  // ─── Sections ────────────────────────────────────────────────────────────────

  Widget _categorySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Category'),
      DropdownButtonFormField<GoalCategory>(
        initialValue: _category,
        dropdownColor: AppColors.surface3,
        style: AppText.bodyM,
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
          padding: const EdgeInsets.only(top: Spacing.s8),
          child: TextField(
            controller: _customLabel,
            maxLength: 24,
            decoration: const InputDecoration(hintText: 'Custom category label'),
          ),
        ),
      const SizedBox(height: Spacing.s8),
    ]);
  }

  Widget _colorSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Color'),
      Wrap(spacing: Spacing.s12, runSpacing: Spacing.s12, children: [
        for (final c in kGoalPalette)
          GestureDetector(
            // Picking a preset infers the (hidden) category from the color.
            onTap: () => setState(() {
              _color = c;
              _category = _inferCategory(c);
            }),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                    color: _color.toARGB32() == c.toARGB32()
                        ? AppColors.textPrimary
                        : Colors.transparent,
                    width: 2),
              ),
              child: _color.toARGB32() == c.toARGB32()
                  ? const Icon(LucideIcons.check,
                      size: 16, color: AppColors.surface0)
                  : null,
            ),
          ),
        // Custom hex swatch — selecting a non-preset color implies category Custom.
        GestureDetector(
          onTap: _pickCustomHex,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _isCustomColor ? _color : AppColors.surface2,
              shape: BoxShape.circle,
              border: Border.all(
                  color: _isCustomColor
                      ? AppColors.textPrimary
                      : AppColors.divider,
                  width: 2),
            ),
            child: Icon(LucideIcons.pipette,
                size: 15,
                color: _isCustomColor
                    ? AppColors.surface0
                    : AppColors.textSecondary),
          ),
        ),
      ]),
      const SizedBox(height: Spacing.s16),
    ]);
  }

  /// True when the current color isn't one of the presets.
  bool get _isCustomColor =>
      !kGoalPalette.any((c) => c.toARGB32() == _color.toARGB32());

  /// Maps a preset color back to its category; anything else is Custom.
  GoalCategory _inferCategory(Color c) {
    final v = c.toARGB32();
    if (v == kCatHealth.toARGB32()) return GoalCategory.health;
    if (v == kCatStudy.toARGB32()) return GoalCategory.study;
    if (v == kCatHome.toARGB32()) return GoalCategory.home;
    if (v == kCatPersonal.toARGB32()) return GoalCategory.personal;
    return GoalCategory.custom;
  }

  Future<void> _pickCustomHex() async {
    final ctrl = TextEditingController(
        text: '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}');
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom color'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '#RRGGBB'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _parseHex(ctrl.text)),
            child: const Text('Use'),
          ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _color = picked;
        _category = GoalCategory.custom;
      });
    }
  }

  static Color? _parseHex(String s) {
    var h = s.trim().replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  Widget _trackedSection() {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Metric'),
        DropdownButtonFormField<TrackedMetric>(
          initialValue: _metric,
          dropdownColor: AppColors.surface3,
          style: AppText.bodyM,
          items: TrackedMetric.values
              .map((m) => DropdownMenuItem(value: m, child: Text(_metricLabel(m))))
              .toList(),
          onChanged: (m) => setState(() => _metric = m ?? _metric),
        ),
        const SizedBox(height: Spacing.s12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Comparator'),
              _segmented<Comparator>(Comparator.values, _comparator,
                  (c) => c == Comparator.lessThanOrEqual ? '≤' : '≥',
                  (c) => setState(() => _comparator = c)),
            ]),
          ),
          const SizedBox(width: Spacing.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Target'),
              TextField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppText.tabular(AppText.bodyM),
                decoration: const InputDecoration(hintText: 'e.g. 2200'),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: Spacing.s12),
        _label('Period'),
        _segmented<GoalPeriod>(GoalPeriod.values, _period,
            (p) => p.name[0].toUpperCase() + p.name.substring(1), (p) => setState(() => _period = p)),
        if (_metric == TrackedMetric.exerciseSessionCount) ...[
          const SizedBox(height: Spacing.s12),
          _label('Min session duration (min)'),
          TextField(
            controller: _minDur,
            keyboardType: TextInputType.number,
            style: AppText.tabular(AppText.bodyM),
            decoration: const InputDecoration(hintText: '20'),
          ),
        ],
      ]),
    );
  }

  // Start date is a Simple-zone field (always visible).
  Widget _startDateField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Start date'),
      _tappableValue(DateFormat('EEE, MMM d, yyyy').format(_startDate), LucideIcons.calendar, () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _startDate = dateOnly(picked));
      }),
    ]);
  }

  // Optional time-of-day lives in the Advanced zone.
  Widget _timeSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.calendarAmber,
        title: Text('Set a time', style: AppText.bodyL),
        value: _timeEnabled,
        onChanged: (v) => setState(() => _timeEnabled = v),
      ),
      if (_timeEnabled)
        _tappableValue(_time.format(context), LucideIcons.clock, () async {
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
        const SizedBox(height: Spacing.s12),
        Row(children: [
          _miniToggle('Specific days', !_weeklyCountMode, () => setState(() => _weeklyCountMode = false)),
          const SizedBox(width: Spacing.s8),
          _miniToggle('N / week', _weeklyCountMode, () => setState(() => _weeklyCountMode = true)),
        ]),
        const SizedBox(height: Spacing.s12),
        if (!_weeklyCountMode)
          Wrap(spacing: Spacing.s8, children: [
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
        const SizedBox(height: Spacing.s8),
        _tappableValue(DateFormat('MMM d, yyyy').format(_until), LucideIcons.calendarDays, () async {
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
        Text('Set a time above to enable reminders',
            style: AppText.bodyS.copyWith(color: AppColors.textTertiary))
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
          const SizedBox(height: Spacing.s8),
          TextField(
            controller: _customReminder,
            keyboardType: TextInputType.number,
            style: AppText.tabular(AppText.bodyM),
            decoration: const InputDecoration(hintText: 'Minutes before', suffixText: 'min'),
          ),
        ],
      ],
    ]);
  }

  // ─── Small UI helpers ────────────────────────────────────────────────────────

  Widget _field(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_label(label), child, const SizedBox(height: Spacing.s8)],
      );

  Widget _label(String t) => Padding(
        padding:
            const EdgeInsets.only(bottom: Spacing.s8, top: Spacing.s4),
        child: Text(t.toUpperCase(), style: AppText.caption),
      );

  Widget _segmented<T>(List<T> values, T current, String Function(T) label, ValueChanged<T> onChanged) {
    return Row(
      children: [
        for (final v in values)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: AppMotion.enter,
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: Spacing.s8),
                padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(
                    color: v == current
                        ? AppColors.calendarAmber
                        : AppColors.surface2,
                    width: v == current ? AppMotion.focusBorderWidth : 1,
                  ),
                  boxShadow: v == current
                      ? AppMotion.accentGlow(AppColors.calendarAmber)
                      : null,
                ),
                child: Text(label(v),
                    textAlign: TextAlign.center,
                    style: AppText.bodyS.copyWith(
                        color: v == current
                            ? AppColors.calendarAmber
                            : AppColors.textSecondary)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _miniToggle(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.enter,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s12, vertical: Spacing.s8),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(
              color: active ? AppColors.calendarAmber : AppColors.surface2,
              width: active ? AppMotion.focusBorderWidth : 1,
            ),
            boxShadow: active
                ? AppMotion.accentGlow(AppColors.calendarAmber)
                : null,
          ),
          child: Text(label,
              style: AppText.bodyS.copyWith(
                  color: active
                      ? AppColors.calendarAmber
                      : AppColors.textSecondary)),
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
      child: AnimatedContainer(
        duration: AppMotion.enter,
        curve: Curves.easeOutCubic,
        width: 34, height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? AppColors.calendarAmber : AppColors.surface2,
            width: active ? AppMotion.focusBorderWidth : 1,
          ),
          boxShadow:
              active ? AppMotion.accentGlow(AppColors.calendarAmber) : null,
        ),
        child: Text(labels[weekday - 1],
            style: AppText.bodyS.copyWith(
                color: active
                    ? AppColors.calendarAmber
                    : AppColors.textSecondary)),
      ),
    );
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) => Row(children: [
        Expanded(child: Text(label, style: AppText.bodyM)),
        IconButton(
          icon: const Icon(LucideIcons.minusCircle,
              color: AppColors.textSecondary),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: AppText.tabular(AppText.titleM)),
        IconButton(
          icon: const Icon(LucideIcons.plusCircle,
              color: AppColors.textSecondary),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ]);

  Widget _tappableValue(String text, IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
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
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: Spacing.s12),
            Text(text, style: AppText.tabular(AppText.bodyM)),
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
