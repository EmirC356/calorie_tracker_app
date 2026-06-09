/**
 * Squad notifications (FCM) — Cloud Functions (2nd gen). Requires the Blaze
 * plan. Deploy: `cd firebase && firebase deploy --only functions`.
 *
 *  - onEntryStatusHit: when a member's day status transitions to 'hit', push
 *    "{name} hit their goal" to the other squad members.
 *  - onReactionCreated: when someone nudges a member, push the emoji to them.
 *  - scheduledSummary: hourly; at each user's local 22:00, push a per-squad
 *    "X of Y squadmates hit their goals today" summary.
 *
 * Recipients muted for a squad (members/{uid}.muted == true) are skipped.
 */
import {onDocumentWritten, onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

async function tokensForUser(uid: string): Promise<string[]> {
  const snap = await db.doc(`users/${uid}`).get();
  return (snap.get("fcmTokens") as string[] | undefined) ?? [];
}

async function isMuted(squadId: string, uid: string): Promise<boolean> {
  const m = await db.doc(`squads/${squadId}/members/${uid}`).get();
  return m.get("muted") === true;
}

async function memberName(squadId: string, uid: string): Promise<string> {
  const m = await db.doc(`squads/${squadId}/members/${uid}`).get();
  return (m.get("displayName") as string | undefined) ?? "A squadmate";
}

/** Sends to each uid's tokens (skipping muted recipients). */
async function pushToUsers(
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

function glyph(emoji: string): string {
  return emoji === "fire" ? "🔥" : emoji === "flex" ? "💪" : "👏";
}

function localDateKey(utc: Date, tzMinutes: number): string {
  const local = new Date(utc.getTime() + tzMinutes * 60000);
  const y = local.getUTCFullYear();
  const m = String(local.getUTCMonth() + 1).padStart(2, "0");
  const d = String(local.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** UTC date key for [days] days ago. */
function dateKeyDaysAgo(days: number): string {
  const d = new Date(Date.now() - days * 86400000);
  const y = d.getUTCFullYear();
  const mo = String(d.getUTCMonth() + 1).padStart(2, "0");
  const da = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${mo}-${da}`;
}

export const onEntryStatusHit = onDocumentWritten(
  "squads/{squadId}/days/{date}/entries/{uid}",
  async (event) => {
    const before = event.data?.before?.get("status");
    const after = event.data?.after?.get("status");
    if (after !== "hit" || before === "hit") return; // only the transition INTO hit
    const {squadId, uid} = event.params as {squadId: string; uid: string};
    const squad = await db.doc(`squads/${squadId}`).get();
    const members = (squad.get("memberUids") as string[] | undefined) ?? [];
    const others = members.filter((m) => m !== uid);
    if (others.length === 0) return;
    const name = await memberName(squadId, uid);
    await pushToUsers(others, squadId, "Goal hit 💪", `${name} hit their goal today!`);
  },
);

export const onReactionCreated = onDocumentCreated(
  "squads/{squadId}/days/{date}/reactions/{rid}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const {squadId} = event.params as {squadId: string};
    const toUid = data.toUid as string;
    const fromName = (data.fromName as string | undefined) ?? "A squadmate";
    await pushToUsers([toUid], squadId, "New nudge", `${fromName} sent you ${glyph(data.emoji as string)}`);
  },
);

/**
 * Deletes day buckets (squads/{id}/days/{YYYY-MM-DD} + their entries/reactions
 * subcollections) older than 30 days, across all squads. Runs once daily.
 *
 * Trade-offs / why server-side: a client-side prune was the documented
 * alternative, but the security rules only let a user delete THEIR OWN
 * entries/reactions — so no client can clear another member's docs in a day
 * bucket. The admin SDK here bypasses rules and prunes globally in one pass
 * (no per-client redundancy or battery cost). `listDocuments()` is used because
 * day docs are path-only parents (the {date} doc itself is never written), and
 * `recursiveDelete` removes the entries/reactions beneath each. Date keys are
 * YYYY-MM-DD so a lexicographic `<` compare equals a chronological one.
 */
export const pruneOldDays = onSchedule("every 24 hours", async () => {
  const cutoff = dateKeyDaysAgo(30);
  const squads = await db.collection("squads").get();
  let pruned = 0;
  for (const sq of squads.docs) {
    const dayRefs = await db.collection(`squads/${sq.id}/days`).listDocuments();
    for (const dayRef of dayRefs) {
      if (dayRef.id < cutoff) {
        await db.recursiveDelete(dayRef);
        pruned++;
      }
    }
  }
  console.log(`pruneOldDays: removed ${pruned} day bucket(s) older than ${cutoff}`);
});

export const scheduledSummary = onSchedule("every 60 minutes", async () => {
  const targetLocalHour = 22; // 10pm local
  const nowUtc = new Date();
  const usersSnap = await db.collection("users").get();

  for (const userDoc of usersSnap.docs) {
    const tz = (userDoc.get("tzOffsetMinutes") as number | undefined) ?? 0;
    const localHour = new Date(nowUtc.getTime() + tz * 60000).getUTCHours();
    if (localHour !== targetLocalHour) continue;

    const uid = userDoc.id;
    const tokens = (userDoc.get("fcmTokens") as string[] | undefined) ?? [];
    if (tokens.length === 0) continue;

    const squadsSnap = await db.collection("squads").where("memberUids", "array-contains", uid).get();
    for (const sq of squadsSnap.docs) {
      if (await isMuted(sq.id, uid)) continue;
      const members = (sq.get("memberUids") as string[] | undefined) ?? [];
      const dateKey = localDateKey(nowUtc, tz);
      const entries = await db.collection(`squads/${sq.id}/days/${dateKey}/entries`).get();
      const hits = entries.docs.filter((d) => d.get("status") === "hit").length;
      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: (sq.get("name") as string | undefined) ?? "Squad",
          body: `${hits} of ${members.length} squadmates hit their goals today.`,
        },
      });
    }
  }
});
