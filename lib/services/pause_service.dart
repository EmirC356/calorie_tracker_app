import '../models/index.dart';
import 'database_service.dart';
import 'squad_service.dart';

/// Orchestrates declaring a squad pause: validates against the yearly cap /
/// window (with a Jan-1 reset of the tally), writes the member's pause object to
/// Firestore, and records a local history row. Pure validation lives in
/// [SquadPause.planPause]; this is the IO layer.
class PauseService {
  final SquadService _squad;
  final DatabaseService _db;

  PauseService({SquadService? squad, DatabaseService? db})
      : _squad = squad ?? SquadService(),
        _db = db ?? DatabaseService();

  /// Validates and (when ok) writes the pause. Returns the [PausePlan] so the UI
  /// can surface a rejection reason (e.g. yearly cap reached).
  Future<PausePlan> declarePause({
    required String squadId,
    required String uid,
    required DateTime until,
    String? reason,
    DateTime? now,
  }) async {
    final theNow = now ?? DateTime.now();
    final member = await _squad.getMember(squadId, uid);
    var current = member?.pause ?? const SquadPause();

    // Yearly reset: the tally is per calendar year (resets Jan 1).
    if (current.declaredAt != null && current.declaredAt!.year < theNow.year) {
      current = current.copyWith(daysUsedThisYear: 0);
    }

    final plan = SquadPause.planPause(current: current, now: theNow, until: until);
    if (!plan.ok) return plan;

    final pause = SquadPause(
      active: true,
      until: dateOnly(until),
      reason: (reason != null && reason.trim().isNotEmpty) ? reason.trim() : null,
      declaredAt: theNow,
      daysUsedThisYear: plan.daysUsedThisYearAfter,
      windowDays: plan.days,
    );
    await _squad.setPause(squadId, uid, pause);
    await _db.insertPauseHistory(
      squadId: squadId, until: until, reason: reason, days: plan.days, declaredAt: theNow);
    return plan;
  }

  /// Ends an active pause early. Deactivates it and refunds the unused days back
  /// to the yearly tally (you only "spend" the days you were actually paused).
  Future<void> resumePause({
    required String squadId,
    required String uid,
    DateTime? now,
  }) async {
    final theNow = now ?? DateTime.now();
    final member = await _squad.getMember(squadId, uid);
    final cur = member?.pause;
    if (cur == null || !cur.active) return;

    var used = cur.windowDays;
    if (cur.declaredAt != null) {
      final elapsed = dateOnly(theNow).difference(dateOnly(cur.declaredAt!)).inDays + 1;
      used = elapsed.clamp(0, cur.windowDays);
    }
    final refund = cur.windowDays - used;
    final newTally = (cur.daysUsedThisYear - refund).clamp(0, SquadPause.maxDaysPerYear);

    await _squad.setPause(squadId, uid,
        cur.copyWith(active: false, daysUsedThisYear: newTally, windowDays: 0));
  }
}
