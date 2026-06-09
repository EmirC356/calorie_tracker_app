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

/** Sends a squad-attributed push to each uid's tokens (skipping muted ones). */
export async function pushToUsers(
  uids: string[],
  squadId: string,
  title: string,
  body: string,
): Promise<void> {
  const lists = await Promise.all(
    uids.map(async (uid) => ((await isMuted(squadId, uid)) ? [] : tokensForUser(uid))),
  );
  const tokens = lists.flat();
  if (tokens.length === 0) return;
  await messaging.sendEachForMulticast({tokens, notification: {title, body}});
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
