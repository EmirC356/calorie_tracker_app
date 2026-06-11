/**
 * Shared Firebase Admin handle + FCM helpers used by both the Squad functions
 * (index.ts) and the Goals/Calendar functions (calendar.ts). admin.initializeApp
 * runs once here (module is cached), so neither importer calls it again.
 */
import * as admin from "firebase-admin";

admin.initializeApp();
export const db = admin.firestore();
export const messaging = admin.messaging();

export async function tokensForUser(uid: string): Promise<string[]> {
  const snap = await db.doc(`users/${uid}`).get();
  return (snap.get("fcmTokens") as string[] | undefined) ?? [];
}

export async function isMuted(squadId: string, uid: string): Promise<boolean> {
  const m = await db.doc(`squads/${squadId}/members/${uid}`).get();
  return m.get("muted") === true;
}

export async function memberName(squadId: string, uid: string): Promise<string> {
  const m = await db.doc(`squads/${squadId}/members/${uid}`).get();
  return (m.get("displayName") as string | undefined) ?? "A squadmate";
}

/**
 * Sends one notification to a flat list of tokens and prunes any that FCM
 * reports as unregistered/invalid from the owning users' `fcmTokens` arrays.
 * `tokenOwner` maps each token back to its uid so cleanup targets the right doc.
 */
export async function sendToTokens(
  tokens: string[],
  tokenOwner: Map<string, string>,
  title: string,
  body: string,
): Promise<void> {
  if (tokens.length === 0) return;
  const res = await messaging.sendEachForMulticast({tokens, notification: {title, body}});
  if (res.failureCount === 0) return;
  // Collect invalid tokens per-user, then strip them with arrayRemove.
  const stale = new Map<string, string[]>();
  res.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      const token = tokens[i];
      const uid = tokenOwner.get(token);
      if (!uid) return;
      (stale.get(uid) ?? stale.set(uid, []).get(uid)!).push(token);
    }
  });
  await Promise.all(
    [...stale.entries()].map(([uid, bad]) =>
      db.doc(`users/${uid}`).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...bad),
      }).catch(() => undefined),
    ),
  );
}

/** Sends a squad-attributed push to each uid's tokens (skipping muted ones). */
export async function pushToUsers(
  uids: string[],
  squadId: string,
  title: string,
  body: string,
): Promise<void> {
  const owner = new Map<string, string>();
  const lists = await Promise.all(
    uids.map(async (uid) => {
      if (await isMuted(squadId, uid)) return [] as string[];
      const toks = await tokensForUser(uid);
      for (const t of toks) owner.set(t, uid);
      return toks;
    }),
  );
  await sendToTokens(lists.flat(), owner, title, body);
}

export function glyph(emoji: string): string {
  return emoji === "fire" ? "🔥" : emoji === "flex" ? "💪" : "👏";
}

export function localDateKey(utc: Date, tzMinutes: number): string {
  const local = new Date(utc.getTime() + tzMinutes * 60000);
  const y = local.getUTCFullYear();
  const m = String(local.getUTCMonth() + 1).padStart(2, "0");
  const d = String(local.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** UTC date key (YYYY-MM-DD) for [days] days ago. */
export function dateKeyDaysAgo(days: number): string {
  const d = new Date(Date.now() - days * 86400000);
  const y = d.getUTCFullYear();
  const mo = String(d.getUTCMonth() + 1).padStart(2, "0");
  const da = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${mo}-${da}`;
}

/**
 * Per-user notification preferences (`users/{uid}/notificationPrefs/master`).
 * CREATE-IF-MISSING semantics: a missing doc (or missing field) is treated as
 * all-bools-true with the default quiet-hours window.
 */
export interface NotificationPrefs {
  squadAttributed: boolean;
  personalPress: boolean;
  retros: boolean;
  broadcastStreakLoss: boolean;
  quietHoursStart: string; // "HH:mm"
  quietHoursEnd: string; // "HH:mm"
}

const DEFAULT_PREFS: NotificationPrefs = {
  squadAttributed: true,
  personalPress: true,
  retros: true,
  broadcastStreakLoss: true,
  quietHoursStart: "23:00",
  quietHoursEnd: "07:00",
};

/** Reads a user's master notification prefs, defaulting missing doc/fields. */
export async function notificationPrefs(uid: string): Promise<NotificationPrefs> {
  const snap = await db.doc(`users/${uid}/notificationPrefs/master`).get();
  if (!snap.exists) return {...DEFAULT_PREFS};
  const d = snap.data() ?? {};
  const bool = (k: keyof NotificationPrefs): boolean =>
    typeof d[k] === "boolean" ? (d[k] as boolean) : true;
  const str = (k: keyof NotificationPrefs, fallback: string): string =>
    typeof d[k] === "string" && (d[k] as string).length > 0 ? (d[k] as string) : fallback;
  return {
    squadAttributed: bool("squadAttributed"),
    personalPress: bool("personalPress"),
    retros: bool("retros"),
    broadcastStreakLoss: bool("broadcastStreakLoss"),
    quietHoursStart: str("quietHoursStart", DEFAULT_PREFS.quietHoursStart),
    quietHoursEnd: str("quietHoursEnd", DEFAULT_PREFS.quietHoursEnd),
  };
}

/** Parses "HH:mm" → minutes-since-midnight; NaN-safe (returns null on garbage). */
function parseHm(hm: string): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(hm);
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/**
 * True when the user's LOCAL time (derived from tzOffsetMinutes) falls within
 * the half-open quiet-hours window [start, end). Handles a window that wraps
 * past midnight (e.g. 23:00 → 07:00). An empty/equal window means "always
 * quiet" is avoided: start === end is treated as no quiet hours (never quiet).
 */
export function inQuietHours(
  utc: Date,
  tzMinutes: number,
  start: string,
  end: string,
): boolean {
  const s = parseHm(start);
  const e = parseHm(end);
  if (s === null || e === null || s === e) return false;
  const local = new Date(utc.getTime() + tzMinutes * 60000);
  const cur = local.getUTCHours() * 60 + local.getUTCMinutes();
  return s < e ? cur >= s && cur < e : cur >= s || cur < e;
}

/**
 * ISO-8601 week of a local date: returns {year, week} with Monday as the first
 * day of the week and week 1 containing the year's first Thursday. The key
 * `YYYY-WW` (zero-padded week) is what `weeklyRetros/{YYYY-WW}` uses.
 */
export function isoWeek(local: Date): {year: number; week: number} {
  // Work on a UTC copy of the local Y/M/D so DST/tz is already baked in.
  const d = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()));
  // ISO weekday: Mon=1..Sun=7. Shift to the Thursday of this week.
  const dayNum = d.getUTCDay() === 0 ? 7 : d.getUTCDay();
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const isoYear = d.getUTCFullYear();
  const yearStart = Date.UTC(isoYear, 0, 1);
  const week = Math.ceil(((d.getTime() - yearStart) / 86400000 + 1) / 7);
  return {year: isoYear, week};
}

/** `YYYY-WW` ISO-week key for a local date (e.g. "2026-24"). */
export function isoWeekKey(local: Date): string {
  const {year, week} = isoWeek(local);
  return `${year}-${String(week).padStart(2, "0")}`;
}

/** Local date key for [days] before the given local date (YYYY-MM-DD). */
export function localDateKeyOffset(utc: Date, tzMinutes: number, daysBack: number): string {
  return localDateKey(new Date(utc.getTime() - daysBack * 86400000), tzMinutes);
}
