import 'package:cloud_firestore/cloud_firestore.dart';
import 'date_helpers.dart';

/// Outcome of validating a proposed pause.
enum PauseValidation { ok, alreadyPaused, endInPast, windowTooLong, yearlyCapReached }

/// Result of [SquadPause.planPause]: the verdict plus the computed inclusive
/// paused-day count and the resulting yearly tally.
class PausePlan {
  final PauseValidation validation;
  final int days;
  final int daysUsedThisYearAfter;
  const PausePlan(this.validation, this.days, this.daysUsedThisYearAfter);
  bool get ok => validation == PauseValidation.ok;
}

/// A member's pause/vacation state, stored on `squads/{}/members/{uid}.pause`.
/// Pausing freezes the streak and suppresses ghost detection, streak-loss
/// broadcasts, full-squad-day eligibility and ranking for the paused days.
///
/// [isPausedOn] is the single source of truth for "is this member paused on this
/// day" — every consumer (snapshot, ghost, broadcast, full-squad, retro) calls
/// it rather than re-deriving the window (cross-cutting concern G).
class SquadPause {
  /// Max days a single pause may span forward (rules-enforced).
  static const int maxWindowDays = 21;

  /// Max paused days a member may use per calendar year (rules-enforced).
  static const int maxDaysPerYear = 60;

  final bool active;
  final DateTime? until; // last paused day, inclusive (date-only)
  final String? reason;
  final DateTime? declaredAt;
  final int daysUsedThisYear;

  /// Inclusive day-span of this pause window. Denormalized so the security rules
  /// can enforce the ≤ 21-day window without parsing the [until] date string.
  final int windowDays;

  const SquadPause({
    this.active = false,
    this.until,
    this.reason,
    this.declaredAt,
    this.daysUsedThisYear = 0,
    this.windowDays = 0,
  });

  /// True when [date] falls within the active pause window
  /// [dateOnly(declaredAt) .. until] inclusive.
  bool isPausedOn(DateTime date) {
    if (!active || until == null) return false;
    final d = dateOnly(date);
    final end = dateOnly(until!);
    final start = declaredAt != null ? dateOnly(declaredAt!) : d;
    return !d.isBefore(start) && !d.isAfter(end);
  }

  /// True when the member is paused as of [now] (today within the window).
  bool isCurrentlyPaused(DateTime now) => isPausedOn(now);

  factory SquadPause.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const SquadPause();
    DateTime? safeYmd(Object? v) {
      if (v is! String) return null;
      try {
        return parseYmd(v);
      } catch (_) {
        return null;
      }
    }

    return SquadPause(
      active: (m['active'] as bool?) ?? false,
      until: safeYmd(m['until']),
      reason: m['reason'] as String?,
      declaredAt: (m['declaredAt'] as Timestamp?)?.toDate(),
      daysUsedThisYear: (m['daysUsedThisYear'] as num?)?.toInt() ?? 0,
      windowDays: (m['windowDays'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'active': active,
        if (until != null) 'until': ymd(until!),
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
        'declaredAt': declaredAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(declaredAt!),
        'daysUsedThisYear': daysUsedThisYear,
        'windowDays': windowDays,
      };

  /// Validates a proposed new pause ending on [until] against the current state.
  /// Pure — the service applies year-reset before calling (pass a [current] whose
  /// daysUsedThisYear is 0 in a new calendar year).
  static PausePlan planPause({
    required SquadPause current,
    required DateTime now,
    required DateTime until,
  }) {
    final today = dateOnly(now);
    final end = dateOnly(until);
    final days = end.difference(today).inDays + 1; // inclusive
    final after = current.daysUsedThisYear + (days < 0 ? 0 : days);

    if (current.isCurrentlyPaused(now)) {
      return PausePlan(PauseValidation.alreadyPaused, days, current.daysUsedThisYear);
    }
    if (end.isBefore(today)) {
      return PausePlan(PauseValidation.endInPast, days, current.daysUsedThisYear);
    }
    if (end.difference(today).inDays > maxWindowDays) {
      return PausePlan(PauseValidation.windowTooLong, days, current.daysUsedThisYear);
    }
    if (after > maxDaysPerYear) {
      return PausePlan(PauseValidation.yearlyCapReached, days, after);
    }
    return PausePlan(PauseValidation.ok, days, after);
  }

  SquadPause copyWith({
    bool? active,
    DateTime? until,
    String? reason,
    DateTime? declaredAt,
    int? daysUsedThisYear,
    int? windowDays,
  }) =>
      SquadPause(
        active: active ?? this.active,
        until: until ?? this.until,
        reason: reason ?? this.reason,
        declaredAt: declaredAt ?? this.declaredAt,
        daysUsedThisYear: daysUsedThisYear ?? this.daysUsedThisYear,
        windowDays: windowDays ?? this.windowDays,
      );
}
