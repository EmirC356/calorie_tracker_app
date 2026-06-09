import 'goal.dart';
import 'goal_occurrence.dart';

/// A goal paired with one of its materialized occurrences, for the history list.
class GoalHistoryEntry {
  final Goal goal;
  final GoalOccurrence occurrence;
  const GoalHistoryEntry(this.goal, this.occurrence);

  DateTime get date => occurrence.occurrenceDate;
  OccurrenceStatus get status => occurrence.status;
  String get categoryLabel => goal.categoryLabel;
  bool get edited => occurrence.overrideFlag;
}

/// Per-category outcome tally over a set of history entries.
class CategoryStat {
  final String category;
  final int done;
  final int failed;
  final int skipped;
  final int open;

  const CategoryStat({
    required this.category,
    this.done = 0,
    this.failed = 0,
    this.skipped = 0,
    this.open = 0,
  });

  int get total => done + failed + skipped + open;

  /// Success rate over decided occurrences (done vs failed); skipped and still-
  /// open occurrences are excluded. Returns 0 when nothing is decided.
  double get successRate {
    final decided = done + failed;
    return decided == 0 ? 0 : done / decided;
  }

  CategoryStat _add(OccurrenceStatus s) => CategoryStat(
        category: category,
        done: done + (s == OccurrenceStatus.done ? 1 : 0),
        failed: failed + (s == OccurrenceStatus.failed ? 1 : 0),
        skipped: skipped + (s == OccurrenceStatus.skipped ? 1 : 0),
        open: open + (s == OccurrenceStatus.open ? 1 : 0),
      );
}

/// Aggregates [entries] into a per-category [CategoryStat], keyed by the goal's
/// category label, sorted by total descending. Pure — unit-tested.
Map<String, CategoryStat> categorySuccessRates(List<GoalHistoryEntry> entries) {
  final map = <String, CategoryStat>{};
  for (final e in entries) {
    final key = e.categoryLabel;
    map[key] = (map[key] ?? CategoryStat(category: key))._add(e.status);
  }
  final sorted = map.entries.toList()
    ..sort((a, b) => b.value.total.compareTo(a.value.total));
  return {for (final e in sorted) e.key: e.value};
}
