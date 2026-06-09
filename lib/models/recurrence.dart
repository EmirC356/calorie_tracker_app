/// Recurrence rules for a [Goal]. Serialized as `{type, params}` JSON into the
/// `goals.recurrence_json` column.
///
/// Weekday bitmask convention (used by [RecurrenceWeekly]):
///   Mon = 1, Tue = 2, Wed = 4, Thu = 8, Fri = 16, Sat = 32, Sun = 64
/// i.e. `1 << (weekday - 1)` with ISO weekdays (Mon = 1 … Sun = 7).
library;

/// Bit for an ISO [weekday] (Mon=1 … Sun=7) in the [RecurrenceWeekly] mask.
int weekdayBit(int isoWeekday) => 1 << (isoWeekday - 1);

const int kMon = 1, kTue = 2, kWed = 4, kThu = 8, kFri = 16, kSat = 32, kSun = 64;

sealed class Recurrence {
  const Recurrence();

  /// Stable discriminator stored in JSON.
  String get type;

  /// Type-specific parameters.
  Map<String, dynamic> paramsJson();

  Map<String, dynamic> toJson() => {'type': type, 'params': paramsJson()};

  factory Recurrence.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final p = (json['params'] as Map?)?.cast<String, dynamic>() ?? const {};
    switch (type) {
      case 'none':
        return const RecurrenceNone();
      case 'daily':
        return const RecurrenceDaily();
      case 'weekly':
        return RecurrenceWeekly(
          weekdaysMask: (p['weekdaysMask'] as num?)?.toInt() ?? 0,
          nTimesPerWeek: (p['nTimesPerWeek'] as num?)?.toInt(),
        );
      case 'monthly':
        return RecurrenceMonthly(dayOfMonth: (p['dayOfMonth'] as num).toInt());
      default:
        return const RecurrenceNone();
    }
  }
}

/// One single occurrence on the goal's start date.
class RecurrenceNone extends Recurrence {
  const RecurrenceNone();
  @override
  String get type => 'none';
  @override
  Map<String, dynamic> paramsJson() => const {};
}

/// Every day from the start date.
class RecurrenceDaily extends Recurrence {
  const RecurrenceDaily();
  @override
  String get type => 'daily';
  @override
  Map<String, dynamic> paramsJson() => const {};
}

/// Weekly recurrence. A weekly rule is EITHER day-specific (a [weekdaysMask] of
/// one or more ISO weekdays) OR count-based ([nTimesPerWeek] occurrences with no
/// fixed day) — never both. When count-based, the recurrence engine emits one
/// anchor occurrence per ISO week, dated to that week's Monday.
class RecurrenceWeekly extends Recurrence {
  /// Bitmask of ISO weekdays (see [weekdayBit]); 0 when count-based.
  final int weekdaysMask;

  /// Number of sessions per week; null when day-specific.
  final int? nTimesPerWeek;

  const RecurrenceWeekly({this.weekdaysMask = 0, this.nTimesPerWeek});

  /// True when this is the "N times per week" mode rather than day-specific.
  bool get isCountBased => nTimesPerWeek != null;

  /// Whether ISO [weekday] (Mon=1 … Sun=7) is selected in the mask.
  bool includesWeekday(int weekday) => (weekdaysMask & weekdayBit(weekday)) != 0;

  @override
  String get type => 'weekly';
  @override
  Map<String, dynamic> paramsJson() =>
      {'weekdaysMask': weekdaysMask, 'nTimesPerWeek': nTimesPerWeek};
}

/// Monthly recurrence on a fixed day of the month.
///
/// [dayOfMonth] is capped to 1–28. We cap at 28 because every month — including
/// February in non-leap years — has a 28th, so a monthly goal never silently
/// skips a month or lands on a non-existent date (e.g. the 30th in February).
class RecurrenceMonthly extends Recurrence {
  final int dayOfMonth;
  RecurrenceMonthly({required int dayOfMonth})
      : dayOfMonth = dayOfMonth.clamp(1, 28);

  @override
  String get type => 'monthly';
  @override
  Map<String, dynamic> paramsJson() => {'dayOfMonth': dayOfMonth};
}
