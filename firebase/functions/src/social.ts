/**
 * Social/accountability Cloud Functions (2nd gen, Node 22). Requires Blaze.
 *
 * These build on the squad data model to deliver the "social pressure" layer:
 *  - sendSquadPush: the ONE gateway through which every push in this file goes.
 *    It consults, per recipient and in order, (1) the per-squad mute flag,
 *    (2) the relevant master notification-pref bool, and (3) quiet hours
 *    (local time via tzOffsetMinutes, wrapping past midnight). Any failing gate
 *    DROPS that recipient's push (we do not queue). Tokens are sent + invalid
 *    ones pruned via the shared `sendToTokens`. FCM is never called outside this
 *    helper (and the legacy `pushToUsers` in shared.ts).
 *  - onDayFinalized: on an entry write, after the day has rolled over in the
 *    user's local tz, broadcast a broken >=5-day streak and detect full-squad
 *    days (one-time, guarded).
 *  - scheduledGhostSweep: daily; flags members quiet > 72h as ghosted and nudges
 *    the squad once.
 *  - onAggregateNudge: when squadmates check in on a ghosted member, sends ONE
 *    bundled "N checked in on you" push, deduped to at most one per 24h.
 *  - scheduledSundayRetro: every 15 min; at each user's local Sunday 20:00 (±7m)
 *    builds their weekly retro doc and sends one recap push.
 */
import {onDocumentWritten, onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {
  db, isMuted, tokensForUser, sendToTokens, notificationPrefs, inQuietHours,
  localDateKey, localDateKeyOffset, isoWeekKey, NotificationPrefs,
} from "./shared";

const FieldValue = admin.firestore.FieldValue;
type Pref = keyof Pick<
  NotificationPrefs,
  "squadAttributed" | "personalPress" | "retros" | "broadcastStreakLoss"
>;

interface SquadPushOpts {
  /** Which master-pref bool gates this push. Omit to skip the pref gate. */
  pref?: Pref;
  /** When true, bypass the per-squad mute check (e.g. personal-press). */
  ignoreMute?: boolean;
  /** Override "now" (testing / batched callers). Defaults to new Date(). */
  now?: Date;
}

/**
 * The single squad-push gateway. For each recipient, in order: per-squad mute →
 * master-pref bool → quiet hours. Any gate that fails DROPS that recipient (the
 * push is not queued). Surviving recipients' tokens are collected and sent once,
 * with invalid-token cleanup. Callers must filter the subject uid out of
 * `recipientUids` so we never push a user about themselves.
 */
export async function sendSquadPush(
  squadId: string,
  recipientUids: string[],
  payload: {title: string; body: string},
  opts: SquadPushOpts = {},
): Promise<void> {
  const now = opts.now ?? new Date();
  const owner = new Map<string, string>();

  const lists = await Promise.all(
    [...new Set(recipientUids)].map(async (uid) => {
      // (1) per-squad mute
      if (!opts.ignoreMute && (await isMuted(squadId, uid))) return [] as string[];
      // (2) master-pref bool (missing doc ⇒ true)
      const prefs = await notificationPrefs(uid);
      if (opts.pref && prefs[opts.pref] !== true) return [] as string[];
      // (3) quiet hours in the recipient's local time
      const u = await db.doc(`users/${uid}`).get();
      const tz = (u.get("tzOffsetMinutes") as number | undefined) ?? 0;
      if (inQuietHours(now, tz, prefs.quietHoursStart, prefs.quietHoursEnd)) {
        return [] as string[];
      }
      const toks = (u.get("fcmTokens") as string[] | undefined) ?? [];
      for (const t of toks) owner.set(t, uid);
      return toks;
    }),
  );

  await sendToTokens(lists.flat(), owner, payload.title, payload.body);
}

// ───────────────────────────── onDayFinalized ──────────────────────────────

interface EntryData {
  status?: string;
  paused?: boolean;
  redeemed?: boolean;
}

/**
 * Counts the prior streak ending the day BEFORE `dateKey`: consecutive days that
 * "continue" the streak walking backwards. A day continues if its entry status
 * is 'hit' (non-paused), OR it is a redeemed missed day, OR the member was
 * paused that day (a pause neither breaks nor extends — we skip past it). The
 * walk stops at the first genuine break (missed & !redeemed & !paused) or a day
 * with no entry. Bounded to 60 lookback days to cap reads.
 */
async function priorStreak(squadId: string, uid: string, dateKey: string): Promise<number> {
  let streak = 0;
  let cursor = new Date(`${dateKey}T00:00:00Z`);
  for (let i = 0; i < 60; i++) {
    cursor = new Date(cursor.getTime() - 86400000);
    const k = cursor.toISOString().slice(0, 10);
    const e = await db.doc(`squads/${squadId}/days/${k}/entries/${uid}`).get();
    if (!e.exists) break;
    const d = e.data() as EntryData;
    const paused = d.paused === true || d.status === "paused";
    if (paused) continue; // pause day: neither breaks nor counts
    if (d.status === "hit") {
      streak++;
      continue;
    }
    if (d.status === "missed" && d.redeemed === true) {
      streak++; // a redeemed miss continues the streak
      continue;
    }
    break; // genuine miss → streak ends here
  }
  return streak;
}

export const onDayFinalized = onDocumentWritten(
  "squads/{squadId}/days/{date}/entries/{uid}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return; // deletion — nothing to finalize
    const {squadId, date, uid} = event.params as {squadId: string; date: string; uid: string};
    const entry = after.data() as EntryData;

    // Only act once the day has rolled over in the SUBJECT's local tz, so a
    // 'missed' computed mid-day isn't broadcast prematurely.
    const subjectUserSnap = await db.doc(`users/${uid}`).get();
    const tz = (subjectUserSnap.get("tzOffsetMinutes") as number | undefined) ?? 0;
    const now = new Date();
    const todayLocal = localDateKey(now, tz);
    if (date >= todayLocal) return; // the day hasn't ended locally yet

    const squad = await db.doc(`squads/${squadId}`).get();
    if (!squad.exists) return;
    const members = (squad.get("memberUids") as string[] | undefined) ?? [];
    const others = members.filter((m) => m !== uid);

    await maybeBroadcastStreakLoss(squadId, uid, date, entry, others, now);
    await maybeFullSquadDay(squadId, date, members, now);
  },
);

/** (a) Streak-broken broadcast — see onDayFinalized header. */
async function maybeBroadcastStreakLoss(
  squadId: string,
  uid: string,
  date: string,
  entry: EntryData,
  others: string[],
  now: Date,
): Promise<void> {
  const paused = entry.paused === true || entry.status === "paused";
  const broken = entry.status === "missed" && !paused && entry.redeemed !== true;
  if (!broken) return;

  const streak = await priorStreak(squadId, uid, date);
  if (streak < 5) return;

  // Idempotency: mark this entry so re-triggers don't re-broadcast.
  const entryRef = db.doc(`squads/${squadId}/days/${date}/entries/${uid}`);
  const guard = await db.runTransaction(async (tx) => {
    const snap = await tx.get(entryRef);
    if (snap.get("streakLossBroadcastAt")) return false;
    tx.set(entryRef, {streakLossBroadcastAt: FieldValue.serverTimestamp()}, {merge: true});
    return true;
  });
  if (!guard) return;

  const memberSnap = await db.doc(`squads/${squadId}/members/${uid}`).get();
  const displayName = (memberSnap.get("displayName") as string | undefined) ?? "A squadmate";
  // Sender opt-out wins: if the broken user opted out of OUTGOING streak-loss
  // broadcasts, suppress the squad-wide push entirely (default true).
  const senderBroadcasts = memberSnap.get("broadcastStreakLoss") !== false;

  // Append to the unified activity feed regardless of push gating.
  await db.collection(`squads/${squadId}/activity`).add({
    type: "streakLoss",
    payload: {uid, displayName, length: streak, date},
    createdAt: FieldValue.serverTimestamp(),
  });

  if (senderBroadcasts && others.length > 0) {
    await sendSquadPush(
      squadId,
      others,
      {title: "Streak ended", body: `${displayName}'s ${streak}-day streak just ended.`},
      {pref: "broadcastStreakLoss", now},
    );
  }

  // Gentle personal nudge to the broken user (gated by personalPress).
  await sendSquadPush(
    squadId,
    [uid],
    {title: "Streak ended", body: "Your streak ended. Start a new one today?"},
    {pref: "personalPress", ignoreMute: true, now},
  );
}

/** (b) Full-squad day — see onDayFinalized header. */
async function maybeFullSquadDay(
  squadId: string,
  date: string,
  members: string[],
  now: Date,
): Promise<void> {
  const entriesSnap = await db.collection(`squads/${squadId}/days/${date}/entries`).get();
  const active = entriesSnap.docs.filter((d) => {
    const e = d.data() as EntryData;
    return !(e.paused === true || e.status === "paused");
  });
  if (active.length < 2) return; // need >= 2 non-paused members
  const allHit = active.every((d) => (d.data() as EntryData).status === "hit");
  if (!allHit) return;
  // Every non-paused MEMBER must have an entry (a missing entry ≠ a hit).
  const activeUids = new Set(active.map((d) => d.id));
  const pausedUids = new Set(
    entriesSnap.docs
      .filter((d) => {
        const e = d.data() as EntryData;
        return e.paused === true || e.status === "paused";
      })
      .map((d) => d.id),
  );
  for (const m of members) {
    if (!activeUids.has(m) && !pausedUids.has(m)) return; // a member with no entry → not full
  }

  // One-time guard: a marker doc per day so re-triggers don't double-send.
  const markerRef = db.doc(`squads/${squadId}/days/${date}/markers/fullSquad`);
  const first = await db.runTransaction(async (tx) => {
    const snap = await tx.get(markerRef);
    if (snap.exists) return false;
    tx.set(markerRef, {at: FieldValue.serverTimestamp()});
    return true;
  });
  if (!first) return;

  await db.doc(`squads/${squadId}`).update({fullSquadDays: FieldValue.increment(1)});

  const recovered = active.some((d) => (d.data() as EntryData).redeemed === true);
  const title = recovered ? "Full squad day (recovered!)" : "Full squad day";
  await db.collection(`squads/${squadId}/activity`).add({
    type: "fullSquadDay",
    payload: {date},
    createdAt: FieldValue.serverTimestamp(),
  });
  await sendSquadPush(
    squadId,
    members,
    {title, body: `🔥 Full squad day — everyone hit on ${date}.`},
    {pref: "squadAttributed", now},
  );
}

// ──────────────────────────── scheduledGhostSweep ───────────────────────────

export const scheduledGhostSweep = onSchedule("0 9 * * *", async () => {
  const now = new Date();
  const cutoff = now.getTime() - 72 * 3600 * 1000; // 72h ago
  const squads = await db.collection("squads").get();
  let ghosted = 0;

  for (const sq of squads.docs) {
    const squadId = sq.id;
    const members = (sq.get("memberUids") as string[] | undefined) ?? [];
    const memberSnaps = await db.collection(`squads/${squadId}/members`).get();
    for (const m of memberSnaps.docs) {
      const uid = m.id;
      if (m.get("ghostedSince")) continue; // already ghosted
      const pause = m.get("pause") as {active?: boolean} | undefined;
      if (pause?.active === true) continue; // never ghost a paused member
      const last = m.get("lastActivityAt") as admin.firestore.Timestamp | undefined;
      if (!last) continue; // no activity baseline yet — leave alone
      if (last.toMillis() > cutoff) continue; // active within 72h

      await m.ref.set(
        {
          ghostedSince: FieldValue.serverTimestamp(),
          lastGhostBroadcastAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      ghosted++;
      const displayName = (m.get("displayName") as string | undefined) ?? "A squadmate";
      const others = members.filter((x) => x !== uid);
      if (others.length > 0) {
        await sendSquadPush(
          squadId,
          others,
          {title: "Squad check-in", body: `${displayName} has been quiet for 3 days — say hi?`},
          {pref: "squadAttributed", now},
        );
      }
    }
  }
  console.log(`scheduledGhostSweep: flagged ${ghosted} member(s) as ghosted`);
});

// ───────────────────────────── onAggregateNudge ─────────────────────────────

/**
 * When squadmates check in on a ghosted member, the device appends nudgerUids to
 * `ghostChecks/{date}/aggregateNudges/{ghostedUid}`. This sends ONE bundled push
 * to the ghosted member when that list first becomes non-empty (or a later write
 * grows it), deduped via `sentToGhostedAt` to at most one bundle per 24h.
 */
export const onAggregateNudge = onDocumentWritten(
  "squads/{squadId}/ghostChecks/{date}/aggregateNudges/{ghostedUid}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const {squadId, ghostedUid} = event.params as {squadId: string; ghostedUid: string};
    const nudgers = (after.get("nudgerUids") as string[] | undefined) ?? [];
    const count = nudgers.length;
    if (count === 0) return;

    const ref = after.ref;
    const now = new Date();
    const sent = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const last = snap.get("sentToGhostedAt") as admin.firestore.Timestamp | undefined;
      if (last && now.getTime() - last.toMillis() < 24 * 3600 * 1000) return false;
      tx.set(ref, {sentToGhostedAt: FieldValue.serverTimestamp()}, {merge: true});
      return true;
    });
    if (!sent) return;

    await sendSquadPush(
      squadId,
      [ghostedUid],
      {title: "Your squad", body: `${count} squadmate${count === 1 ? "" : "s"} checked in on you ❤️`},
      {pref: "squadAttributed", now},
    );
  },
);

// ──────────────────────────── scheduledSundayRetro ──────────────────────────

interface RetroPayload {
  weekKey: string;
  personal: {hitDays: number; trackedDays: number; currentStreak: number};
  squads: Array<{
    squadId: string;
    name: string;
    hitRate: number; // 0..1 over the squad's tracked entries this week
    topPerformer: {uid: string; displayName: string; hits: number} | null;
    mostImproved: {uid: string; displayName: string; delta: number} | null;
    streaksAtRisk: Array<{uid: string; displayName: string; streak: number}>;
    fullSquadDays: number;
    groupGoals: Array<{title: string; currentValue: number; target: number; hit: boolean}>;
    intentions: Array<{uid: string; displayName: string; text: string}>;
    pauses: Array<{uid: string; displayName: string; until: string}>;
  }>;
}

/** Inclusive list of the 7 local YYYY-MM-DD keys for the week ending `endLocal` (a Sunday). */
function weekDateKeys(endUtc: Date, tz: number): string[] {
  // endUtc is "now"; the local Sunday is today. Collect Mon..Sun (last 7 days incl. today).
  const keys: string[] = [];
  for (let i = 6; i >= 0; i--) keys.push(localDateKeyOffset(endUtc, tz, i));
  return keys;
}

async function buildRetroForSquad(
  squadId: string,
  uid: string,
  dateKeys: string[],
  weekKey: string,
): Promise<RetroPayload["squads"][number]> {
  const squad = await db.doc(`squads/${squadId}`).get();
  const name = (squad.get("name") as string | undefined) ?? "Squad";
  const members = (squad.get("memberUids") as string[] | undefined) ?? [];

  // Per-member hit counts this week + this/prev half comparison for "most improved".
  const hits = new Map<string, number>(members.map((m) => [m, 0]));
  const firstHalf = new Map<string, number>(members.map((m) => [m, 0]));
  const secondHalf = new Map<string, number>(members.map((m) => [m, 0]));
  let trackedEntries = 0;
  let hitEntries = 0;

  await Promise.all(
    dateKeys.map(async (k, idx) => {
      const entries = await db.collection(`squads/${squadId}/days/${k}/entries`).get();
      for (const e of entries.docs) {
        const d = e.data() as EntryData;
        const paused = d.paused === true || d.status === "paused";
        if (paused) continue;
        trackedEntries++;
        const isHit = d.status === "hit";
        if (isHit) {
          hitEntries++;
          hits.set(e.id, (hits.get(e.id) ?? 0) + 1);
          if (idx < 3) firstHalf.set(e.id, (firstHalf.get(e.id) ?? 0) + 1);
          else secondHalf.set(e.id, (secondHalf.get(e.id) ?? 0) + 1);
        }
      }
    }),
  );

  // displayName lookup from member docs.
  const memberDocs = await db.collection(`squads/${squadId}/members`).get();
  const nameOf = new Map<string, string>();
  const atRisk: RetroPayload["squads"][number]["streaksAtRisk"] = [];
  const pauses: RetroPayload["squads"][number]["pauses"] = [];
  const intentions: RetroPayload["squads"][number]["intentions"] = [];
  for (const md of memberDocs.docs) {
    nameOf.set(md.id, (md.get("displayName") as string | undefined) ?? "Squadmate");
    const pause = md.get("pause") as {active?: boolean; until?: string} | undefined;
    if (pause?.active === true) {
      pauses.push({uid: md.id, displayName: nameOf.get(md.id)!, until: pause.until ?? ""});
    }
  }

  // Weekly intentions live in their own subcollection
  // (squads/{}/intentions/{weekKey}/members/{uid}), NOT on the member doc.
  const intentSnap = await db.collection(`squads/${squadId}/intentions/${weekKey}/members`).get();
  for (const it of intentSnap.docs) {
    const text = (it.get("text") as string | undefined) ?? "";
    if (text) {
      intentions.push({uid: it.id, displayName: nameOf.get(it.id) ?? "Squadmate", text});
    }
  }

  // Top performer = most hits this week.
  let topPerformer: RetroPayload["squads"][number]["topPerformer"] = null;
  for (const [mUid, h] of hits) {
    if (h > 0 && (!topPerformer || h > topPerformer.hits)) {
      topPerformer = {uid: mUid, displayName: nameOf.get(mUid) ?? "Squadmate", hits: h};
    }
  }

  // Most improved = largest secondHalf - firstHalf delta (positive only).
  let mostImproved: RetroPayload["squads"][number]["mostImproved"] = null;
  for (const mUid of members) {
    const delta = (secondHalf.get(mUid) ?? 0) - (firstHalf.get(mUid) ?? 0);
    if (delta > 0 && (!mostImproved || delta > mostImproved.delta)) {
      mostImproved = {uid: mUid, displayName: nameOf.get(mUid) ?? "Squadmate", delta};
    }
  }

  // Streaks-at-risk: members who hit recently but MISSED the last tracked day.
  const lastKey = dateKeys[dateKeys.length - 1];
  for (const mUid of members) {
    const last = await db.doc(`squads/${squadId}/days/${lastKey}/entries/${mUid}`).get();
    const st = priorStreakSafe(squadId, mUid, lastKey);
    const missedLast = last.exists && (last.get("status") === "missed");
    if (missedLast) {
      const s = await st;
      if (s >= 3) atRisk.push({uid: mUid, displayName: nameOf.get(mUid) ?? "Squadmate", streak: s});
    }
  }

  // Group goals snapshot.
  const goalsSnap = await db.collection(`squads/${squadId}/groupGoals`).get();
  const groupGoals = goalsSnap.docs.map((g) => {
    const target = (g.get("target") as number | undefined) ?? 0;
    const current = (g.get("currentValue") as number | undefined) ?? 0;
    return {
      title: (g.get("title") as string | undefined) ?? "Group goal",
      currentValue: current,
      target,
      hit: g.get("hitAt") != null || (target > 0 && current >= target),
    };
  });

  return {
    squadId,
    name,
    hitRate: trackedEntries > 0 ? hitEntries / trackedEntries : 0,
    topPerformer,
    mostImproved,
    streaksAtRisk: atRisk,
    fullSquadDays: (squad.get("fullSquadDays") as number | undefined) ?? 0,
    groupGoals,
    intentions,
    pauses,
  };
}

/** priorStreak that never throws (retro aggregation is best-effort). */
async function priorStreakSafe(squadId: string, uid: string, dateKey: string): Promise<number> {
  try {
    // Count the streak as of `dateKey` inclusive: the day after dateKey.
    const next = new Date(new Date(`${dateKey}T00:00:00Z`).getTime() + 86400000)
      .toISOString()
      .slice(0, 10);
    return await priorStreak(squadId, uid, next);
  } catch {
    return 0;
  }
}

export const scheduledSundayRetro = onSchedule("every 15 minutes", async () => {
  const now = new Date();
  const users = await db.collection("users").get();

  for (const u of users.docs) {
    const uid = u.id;
    const tz = (u.get("tzOffsetMinutes") as number | undefined) ?? 0;
    const local = new Date(now.getTime() + tz * 60000);
    // Target: Sunday (getUTCDay()===0 on the local clock) 20:00 ± 7 min.
    if (local.getUTCDay() !== 0) continue;
    const mins = local.getUTCHours() * 60 + local.getUTCMinutes();
    if (Math.abs(mins - 20 * 60) > 7) continue;

    const weekKey = isoWeekKey(local);
    const retroRef = db.doc(`users/${uid}/weeklyRetros/${weekKey}`);
    if ((await retroRef.get()).exists) continue; // already generated this week

    // Aggregate across the user's squads.
    const dateKeys = weekDateKeys(now, tz);
    const squadsSnap = await db.collection("squads").where("memberUids", "array-contains", uid).get();
    const squadPayloads = await Promise.all(
      squadsSnap.docs.map((s) => buildRetroForSquad(s.id, uid, dateKeys, weekKey).catch(() => null)),
    );
    const squads = squadPayloads.filter((s): s is RetroPayload["squads"][number] => s !== null);

    // Personal week stats: hits across the user's own entries + current streak.
    let hitDays = 0;
    let trackedDays = 0;
    for (const s of squadsSnap.docs) {
      for (const k of dateKeys) {
        const e = await db.doc(`squads/${s.id}/days/${k}/entries/${uid}`).get();
        if (!e.exists) continue;
        const d = e.data() as EntryData;
        if (d.paused === true || d.status === "paused") continue;
        trackedDays++;
        if (d.status === "hit") hitDays++;
      }
    }
    let currentStreak = 0;
    if (squadsSnap.docs.length > 0) {
      currentStreak = await priorStreakSafe(squadsSnap.docs[0].id, uid, dateKeys[dateKeys.length - 1]);
    }

    const payload: RetroPayload = {
      weekKey,
      personal: {hitDays, trackedDays, currentStreak},
      squads,
    };

    await retroRef.set({generatedAt: FieldValue.serverTimestamp(), payload});

    // One recap push, gated by `retros`. Quiet hours defer to next morning 08:00.
    const prefs = await notificationPrefs(uid);
    if (prefs.retros !== true) continue;
    const quiet = inQuietHours(now, tz, prefs.quietHoursStart, prefs.quietHoursEnd);
    const tokens = await tokensForUser(uid);
    if (tokens.length === 0) continue;
    if (quiet) {
      // Defer: stash a pending recap the morning brief (08:00 local) can pick up,
      // rather than dropping the recap entirely.
      await db.doc(`users/${uid}/pendingRetroPush/${weekKey}`).set({
        title: "Squad week recap",
        body: "Squad week recap is ready 📊",
        weekKey,
        deferUntilLocalHour: 8,
        createdAt: FieldValue.serverTimestamp(),
      });
      continue;
    }
    const owner = new Map<string, string>(tokens.map((t) => [t, uid]));
    await sendToTokens(tokens, owner, "Squad week recap", "Squad week recap is ready 📊");
  }
});

/**
 * Delivers any quiet-hours-deferred retro push once the user reaches local 08:00.
 * Co-scheduled at 15-min cadence; idempotent (deletes the pending doc on send).
 */
export const scheduledDeferredRetroPush = onSchedule("every 15 minutes", async () => {
  const now = new Date();
  const users = await db.collection("users").get();
  for (const u of users.docs) {
    const uid = u.id;
    const tz = (u.get("tzOffsetMinutes") as number | undefined) ?? 0;
    const local = new Date(now.getTime() + tz * 60000);
    if (!(local.getUTCHours() === 8 && local.getUTCMinutes() < 15)) continue;
    const pending = await db.collection(`users/${uid}/pendingRetroPush`).get();
    if (pending.empty) continue;
    const prefs = await notificationPrefs(uid);
    const tokens = await tokensForUser(uid);
    for (const p of pending.docs) {
      if (prefs.retros === true && tokens.length > 0) {
        const owner = new Map<string, string>(tokens.map((t) => [t, uid]));
        await sendToTokens(
          tokens,
          owner,
          (p.get("title") as string | undefined) ?? "Squad week recap",
          (p.get("body") as string | undefined) ?? "Squad week recap is ready 📊",
        );
      }
      await p.ref.delete();
    }
  }
});

// ───────────────────────────── onCommentCreated ─────────────────────────────

/**
 * Pushes a new comment to its recipient, THROTTLED to at most one push per 30
 * min per (recipient, sender) — the budget-critical collapse so 5 comments don't
 * become 5 pushes. Subsequent comments inside the window are silently batched
 * (the recipient sees them in-app). Self-comments never push.
 */
export const onCommentCreated = onDocumentCreated(
  "squads/{squadId}/days/{date}/comments/{commentId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const {squadId, date} = event.params as {squadId: string; date: string};
    const c = snap.data() as {fromUid?: string; fromName?: string; toUid?: string; text?: string};
    if (!c.fromUid || !c.toUid || c.fromUid === c.toUid) return; // no self-comment push

    const throttleRef = db.doc(
      `squads/${squadId}/days/${date}/commentPushThrottle/${c.toUid}_${c.fromUid}`,
    );
    const now = new Date();
    const allow = await db.runTransaction(async (tx) => {
      const t = await tx.get(throttleRef);
      const last = t.get("lastPushAt") as admin.firestore.Timestamp | undefined;
      if (last && now.getTime() - last.toMillis() < 30 * 60 * 1000) return false; // batched
      tx.set(throttleRef, {lastPushAt: FieldValue.serverTimestamp()}, {merge: true});
      return true;
    });
    if (!allow) return;

    const fromName = c.fromName ?? "A squadmate";
    const body = (c.text ?? "").slice(0, 60);
    await sendSquadPush(
      squadId,
      [c.toUid],
      {title: `${fromName} commented`, body: `${fromName} commented on your ${date}: "${body}"`},
      {pref: "squadAttributed", now},
    );
  },
);

// ───────────────────────────── onGroupGoalHit ───────────────────────────────

/** Celebrates a group goal the first time its currentValue crosses target. */
export const onGroupGoalHit = onDocumentWritten(
  "squads/{squadId}/groupGoals/{goalId}",
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after?.exists) return;
    const hadHit = before?.exists && before.get("hitAt") != null;
    if (hadHit || after.get("hitAt") == null) return; // only the first hit transition

    const {squadId} = event.params as {squadId: string};
    const title = (after.get("title") as string | undefined) ?? "a group goal";
    const squad = await db.doc(`squads/${squadId}`).get();
    const members = (squad.get("memberUids") as string[] | undefined) ?? [];

    await db.collection(`squads/${squadId}/activity`).add({
      type: "groupGoalHit",
      payload: {title},
      createdAt: FieldValue.serverTimestamp(),
    });
    await sendSquadPush(
      squadId,
      members,
      {title: "Group goal hit 🎯", body: `🎯 You hit '${title}' as a squad`},
      {pref: "squadAttributed"},
    );
  },
);

// ──────────────────────────── onMemberPauseChanged ──────────────────────────

/**
 * Announces a pause / return to the rest of the squad ("Selin paused til Jun 22"
 * / "Selin is back"), once per transition. Guarded by a `lastPauseAnnounce`
 * marker so the frequent member-doc writes (lastActivityAt heartbeats) never
 * re-announce — those don't change pause.active, so they early-return anyway.
 */
export const onMemberPauseChanged = onDocumentWritten(
  "squads/{squadId}/members/{uid}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const before = event.data?.before;
    const wasPaused = (before?.get("pause") as {active?: boolean} | undefined)?.active === true;
    const pause = after.get("pause") as {active?: boolean; until?: string} | undefined;
    const isPaused = pause?.active === true;
    if (wasPaused === isPaused) return; // no pause/return transition

    const {squadId, uid} = event.params as {squadId: string; uid: string};
    const marker = isPaused ? `paused_${pause?.until ?? ""}` : "returned";
    const ref = db.doc(`squads/${squadId}/members/${uid}`);
    const fresh = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.get("lastPauseAnnounce") === marker) return false; // already announced
      tx.set(ref, {lastPauseAnnounce: marker}, {merge: true});
      return true;
    });
    if (!fresh) return;

    const squad = await db.doc(`squads/${squadId}`).get();
    if (!squad.exists) return;
    const members = (squad.get("memberUids") as string[] | undefined) ?? [];
    const others = members.filter((m) => m !== uid);
    const displayName = (after.get("displayName") as string | undefined) ?? "A squadmate";

    await db.collection(`squads/${squadId}/activity`).add({
      type: isPaused ? "pause" : "return",
      payload: {uid, displayName, until: pause?.until ?? ""},
      createdAt: FieldValue.serverTimestamp(),
    });
    if (others.length === 0) return;
    const body = isPaused ?
      `${displayName} paused${pause?.until ? ` til ${pause.until}` : ""} 🌴` :
      `${displayName} is back 💪`;
    await sendSquadPush(squadId, others, {title: "Squad update", body}, {pref: "squadAttributed"});
  },
);
