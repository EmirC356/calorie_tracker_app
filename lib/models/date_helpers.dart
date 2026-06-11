/// Pure date helpers shared by the Goals/Calendar feature. No IO, no Flutter.
///
/// Goal *dates* (a goal's start date, an occurrence's date) are calendar dates
/// in the user's local timezone — they are stored as `YYYY-MM-DD` strings so
/// they never drift across timezones and match the Firestore occurrenceId
/// scheme (`{goalId}_{YYYY-MM-DD}`). Goal *timestamps* (createdAt, doneAt, …)
/// are stored as UTC ISO-8601 instead; see the goal models for those.
///
/// Week start is **Monday** (ISO-8601) everywhere in this feature.
library;

/// Strips the time component, returning local midnight of [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Formats [d] as a zero-padded `YYYY-MM-DD` local calendar date.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Parses a `YYYY-MM-DD` (or any ISO-8601) string back to a local date-only
/// [DateTime]. Tolerant of full timestamps so legacy/full values still load.
DateTime parseYmd(String s) => dateOnly(DateTime.parse(s));

/// The Monday (00:00 local) of the ISO week containing [d].
DateTime mondayOf(DateTime d) {
  final o = dateOnly(d);
  return o.subtract(Duration(days: o.weekday - DateTime.monday));
}

/// The Sunday (00:00 local) of the ISO week containing [d] — i.e. Monday + 6.
DateTime sundayOf(DateTime d) => mondayOf(d).add(const Duration(days: 6));

/// ISO-8601 week key `YYYY-Www` (Monday start; the week's year is the year of
/// its Thursday). Matches the Cloud Functions' week keys for retros/intentions.
String isoWeekKey(DateTime d) {
  final thursday = mondayOf(d).add(const Duration(days: 3));
  final dayOfYear = thursday.difference(DateTime(thursday.year, 1, 1)).inDays;
  final week = (dayOfYear ~/ 7) + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// True when [a] and [b] fall on the same local calendar day.
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Inclusive list of date-only days from [from] to [to].
List<DateTime> daysInRange(DateTime from, DateTime to) {
  final start = dateOnly(from);
  final end = dateOnly(to);
  final out = <DateTime>[];
  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    out.add(d);
  }
  return out;
}
