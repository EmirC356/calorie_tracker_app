/**
 * Goals/Calendar Cloud Functions (2nd gen). Requires Blaze.
 *
 * Design rationale: the device keeps the heavy logic (local SQLite is the source
 * of truth) and uses Firestore as a queue. These functions are simple readers +
 * senders, so we never mirror every goal to the cloud:
 *  - onGoalSuggestionCreated / onGoalSuggestionAccepted: triggered pushes for
 *    the suggestion lifecycle (honor per-squad mute).
 *  - scheduledMorningBrief: every 15 min; at each user's local 08:00 it sends a
 *    brief computed from a `todaysGoalsBrief/{date}` doc the device wrote during
 *    the daily sweep (functions can't read the user's SQLite). Also prunes brief
 *    docs older than 7 days.
 *  - scheduledGoalReminders: every 5 min; fires any `pendingReminders/{occId}`
 *    doc whose `fireAt` has passed (device-written), then deletes it.
 *
 * Suggestion/accept pushes honor per-squad mute. The morning brief and reminders
 * are PERSONAL and gated by a single user flag `goalNotificationsEnabled`
 * (missing == enabled), toggled in Health → Settings → "Goal notifications".
 */
import {onDocumentWritten, onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, messaging, memberName, pushToUsers, dateKeyDaysAgo, localDateKey} from "./shared";

function goalTitle(payloadJson?: string): string {
  try {
    return (JSON.parse(payloadJson ?? "{}").title as string) || "a goal";
  } catch {
    return "a goal";
  }
}

export const onGoalSuggestionCreated = onDocumentCreated(
  "squads/{squadId}/suggestions/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const {squadId} = event.params as {squadId: string};
    const toUid = data.toUid as string;
    const fromName = (data.fromName as string | undefined) ?? "A squadmate";
    await pushToUsers(
      [toUid], squadId, "New goal suggestion",
      `${fromName} suggested a goal: '${goalTitle(data.payloadJson as string)}'`,
    );
  },
);

export const onGoalSuggestionAccepted = onDocumentWritten(
  "squads/{squadId}/suggestions/{id}",
  async (event) => {
    const before = event.data?.before?.get("status");
    const after = event.data?.after?.get("status");
    if (before !== "pending" || after !== "accepted") return; // only this transition
    const data = event.data?.after?.data();
    if (!data) return;
    const {squadId} = event.params as {squadId: string};
    const fromUid = data.fromUid as string;
    const toName = await memberName(squadId, data.toUid as string);
    await pushToUsers(
      [fromUid], squadId, "Goal accepted 🎉",
      `${toName} accepted your goal: '${goalTitle(data.payloadJson as string)}'`,
    );
  },
);

export const scheduledMorningBrief = onSchedule("every 15 minutes", async () => {
  const nowUtc = new Date();
  const users = await db.collection("users").get();

  for (const u of users.docs) {
    if (u.get("goalNotificationsEnabled") === false) continue;
    const tz = (u.get("tzOffsetMinutes") as number | undefined) ?? 0;
    const local = new Date(nowUtc.getTime() + tz * 60000);
    // Exactly one 15-min cron run per day lands in [08:00, 08:15) local.
    if (!(local.getUTCHours() === 8 && local.getUTCMinutes() < 15)) continue;

    // Housekeeping: drop brief docs older than 7 days.
    const cutoff = dateKeyDaysAgo(7);
    const briefs = await db.collection(`users/${u.id}/todaysGoalsBrief`).listDocuments();
    for (const ref of briefs) {
      if (ref.id < cutoff) await ref.delete();
    }

    const tokens = (u.get("fcmTokens") as string[] | undefined) ?? [];
    if (tokens.length === 0) continue;
    const dateKey = localDateKey(nowUtc, tz);
    const brief = await db.doc(`users/${u.id}/todaysGoalsBrief/${dateKey}`).get();
    if (!brief.exists) continue;
    const count = (brief.get("goalsCount") as number | undefined) ?? 0;
    if (count === 0) continue;
    const items = (brief.get("items") as Array<{title: string}> | undefined) ?? [];
    const preview = items.slice(0, 3).map((i) => i.title).join(", ");
    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: "Today's goals ☀️",
        body: `${count} goal${count === 1 ? "" : "s"} today${preview ? `: ${preview}` : ""}`,
      },
    });
  }
});

export const scheduledGoalReminders = onSchedule("every 5 minutes", async () => {
  const now = Date.now();
  const users = await db.collection("users").get();

  for (const u of users.docs) {
    const enabled = u.get("goalNotificationsEnabled") !== false;
    const tokens = (u.get("fcmTokens") as string[] | undefined) ?? [];
    const pending = await db.collection(`users/${u.id}/pendingReminders`).get();
    for (const r of pending.docs) {
      const fireAt = Date.parse((r.get("fireAt") as string | undefined) ?? "");
      if (isNaN(fireAt) || fireAt > now) continue; // not due yet
      if (enabled && tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: "Goal reminder ⏰",
            body: (r.get("title") as string | undefined) ?? "You have a goal coming up",
          },
        });
      }
      await r.ref.delete(); // fired (or skipped) → don't accumulate
    }
  }
});
