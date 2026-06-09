import 'dart:convert';
import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'recurrence.dart';
import 'date_helpers.dart';

/// Goal category. `custom` carries a free-text [Goal.customCategoryLabel].
enum GoalCategory { health, study, home, personal, custom }

enum GoalPriority { low, medium, high }

/// Manual goals are checked off by hand; tracked goals are auto-evaluated
/// against the app's existing meal/exercise/weight data (see GoalEvaluator).
enum GoalType { manual, tracked }

/// The app metric a tracked goal is measured against.
enum TrackedMetric {
  kcalTotal,
  proteinG,
  exerciseMinutes,
  exerciseSessionCount,
  weightDeltaKg,
  waterMl,
}

/// Cap-style (`lessThanOrEqual`) vs floor-style (`greaterThanOrEqual`) targets.
enum Comparator { lessThanOrEqual, greaterThanOrEqual }

/// The window a tracked metric is summed/evaluated over.
enum GoalPeriod { day, week }

/// A goal definition — the reusable "ticket" that occurrences are generated
/// from by the recurrence engine. Dates are local calendar dates (`YYYY-MM-DD`);
/// [createdAt] is a UTC timestamp.
class Goal {
  final int? id;
  final String title;
  final String? description;
  final GoalCategory category;
  final String? customCategoryLabel;
  final Color color;
  final GoalPriority priority;
  final GoalType type;

  // Tracked-only fields:
  final TrackedMetric? metric;
  final Comparator? comparator;
  final double? target;
  final GoalPeriod? period;
  final int? minDurationMin; // for exerciseSessionCount; default 20

  // Schedule:
  final DateTime startDate; // local date-only
  final TimeOfDay? timeOfDay;
  final Recurrence recurrence;
  final int? endDateDaysFromStart; // optional series end; null = forever

  // Squad:
  final bool squadVisible;

  // Reminders:
  final int? reminderMinutesBefore; // null = no reminder
  final bool morningBriefIncluded;

  // Meta:
  final DateTime createdAt; // UTC timestamp
  final bool archived;

  Goal({
    this.id,
    required this.title,
    this.description,
    required this.category,
    this.customCategoryLabel,
    required this.color,
    this.priority = GoalPriority.medium,
    this.type = GoalType.manual,
    this.metric,
    this.comparator,
    this.target,
    this.period,
    this.minDurationMin,
    required this.startDate,
    this.timeOfDay,
    this.recurrence = const RecurrenceNone(),
    this.endDateDaysFromStart,
    this.squadVisible = false,
    this.reminderMinutesBefore,
    this.morningBriefIncluded = true,
    required this.createdAt,
    this.archived = false,
  });

  bool get isTracked => type == GoalType.tracked;

  /// The minimum session duration used by `exerciseSessionCount` goals.
  int get effectiveMinDurationMin => minDurationMin ?? 20;

  /// Display label for the category (the free-text label when custom).
  String get categoryLabel => category == GoalCategory.custom
      ? (customCategoryLabel?.trim().isNotEmpty == true
          ? customCategoryLabel!.trim()
          : 'Custom')
      : category.name[0].toUpperCase() + category.name.substring(1);

  /// Inclusive last date this series can occur on, or null if it recurs
  /// forever. `endDateDaysFromStart == 0` means the series ends on the start
  /// date (single effective day).
  DateTime? get seriesEndDate => endDateDaysFromStart == null
      ? null
      : dateOnly(startDate).add(Duration(days: endDateDaysFromStart!));

  Goal copyWith({
    int? id,
    String? title,
    String? description,
    GoalCategory? category,
    String? customCategoryLabel,
    Color? color,
    GoalPriority? priority,
    GoalType? type,
    TrackedMetric? metric,
    Comparator? comparator,
    double? target,
    GoalPeriod? period,
    int? minDurationMin,
    DateTime? startDate,
    TimeOfDay? timeOfDay,
    Recurrence? recurrence,
    int? endDateDaysFromStart,
    bool? squadVisible,
    int? reminderMinutesBefore,
    bool? morningBriefIncluded,
    DateTime? createdAt,
    bool? archived,
    bool clearDescription = false,
    bool clearCustomCategoryLabel = false,
    bool clearTracked = false,
    bool clearTimeOfDay = false,
    bool clearEndDate = false,
    bool clearReminder = false,
  }) =>
      Goal(
        id: id ?? this.id,
        title: title ?? this.title,
        description:
            clearDescription ? null : (description ?? this.description),
        category: category ?? this.category,
        customCategoryLabel: clearCustomCategoryLabel
            ? null
            : (customCategoryLabel ?? this.customCategoryLabel),
        color: color ?? this.color,
        priority: priority ?? this.priority,
        type: type ?? this.type,
        metric: clearTracked ? null : (metric ?? this.metric),
        comparator: clearTracked ? null : (comparator ?? this.comparator),
        target: clearTracked ? null : (target ?? this.target),
        period: clearTracked ? null : (period ?? this.period),
        minDurationMin:
            clearTracked ? null : (minDurationMin ?? this.minDurationMin),
        startDate: startDate ?? this.startDate,
        timeOfDay: clearTimeOfDay ? null : (timeOfDay ?? this.timeOfDay),
        recurrence: recurrence ?? this.recurrence,
        endDateDaysFromStart: clearEndDate
            ? null
            : (endDateDaysFromStart ?? this.endDateDaysFromStart),
        squadVisible: squadVisible ?? this.squadVisible,
        reminderMinutesBefore: clearReminder
            ? null
            : (reminderMinutesBefore ?? this.reminderMinutesBefore),
        morningBriefIncluded: morningBriefIncluded ?? this.morningBriefIncluded,
        createdAt: createdAt ?? this.createdAt,
        archived: archived ?? this.archived,
      );

  /// Row map for the `goals` table. Dates are `YYYY-MM-DD`; [createdAt] is UTC.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'custom_category_label': customCategoryLabel,
        'color_argb': color.toARGB32(),
        'priority': priority.name,
        'type': type.name,
        'metric': metric?.name,
        'comparator': comparator?.name,
        'target': target,
        'period': period?.name,
        'min_duration_min': minDurationMin,
        'start_date': ymd(startDate),
        'time_of_day': _encodeTimeOfDay(timeOfDay),
        'recurrence_json': jsonEncode(recurrence.toJson()),
        'end_date_days_from_start': endDateDaysFromStart,
        'squad_visible': squadVisible ? 1 : 0,
        'reminder_minutes_before': reminderMinutesBefore,
        'morning_brief_included': morningBriefIncluded ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
        'archived': archived ? 1 : 0,
      };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'] as int?,
        title: m['title'] as String,
        description: m['description'] as String?,
        category: _categoryFrom(m['category'] as String?),
        customCategoryLabel: m['custom_category_label'] as String?,
        color: Color((m['color_argb'] as num).toInt()),
        priority: _enumFrom(GoalPriority.values, m['priority'] as String?,
            GoalPriority.medium),
        type: _enumFrom(GoalType.values, m['type'] as String?, GoalType.manual),
        metric: _nullableEnum(TrackedMetric.values, m['metric'] as String?),
        comparator: _nullableEnum(Comparator.values, m['comparator'] as String?),
        target: (m['target'] as num?)?.toDouble(),
        period: _nullableEnum(GoalPeriod.values, m['period'] as String?),
        minDurationMin: (m['min_duration_min'] as num?)?.toInt(),
        startDate: parseYmd(m['start_date'] as String),
        timeOfDay: _decodeTimeOfDay(m['time_of_day'] as String?),
        recurrence: Recurrence.fromJson(
            jsonDecode(m['recurrence_json'] as String) as Map<String, dynamic>),
        endDateDaysFromStart: (m['end_date_days_from_start'] as num?)?.toInt(),
        squadVisible: (m['squad_visible'] as num?)?.toInt() == 1,
        reminderMinutesBefore: (m['reminder_minutes_before'] as num?)?.toInt(),
        morningBriefIncluded:
            (m['morning_brief_included'] as num?)?.toInt() != 0,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        archived: (m['archived'] as num?)?.toInt() == 1,
      );

  /// JSON used for cross-device payloads (goal suggestions). Uses the same
  /// shape as [toMap] but is independent of the DB id.
  Map<String, dynamic> toJson() => toMap()..remove('id');

  factory Goal.fromJson(Map<String, dynamic> json) => Goal.fromMap(json);

  static GoalCategory _categoryFrom(String? name) =>
      _enumFrom(GoalCategory.values, name, GoalCategory.custom);

  static T _enumFrom<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  static T? _nullableEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static String? _encodeTimeOfDay(TimeOfDay? t) =>
      t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? _decodeTimeOfDay(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
