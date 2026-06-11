/**
 * Birthday celebration push (2nd gen, Node 22). Requires Blaze.
 *
 * scheduledBirthdayCheck runs daily at 09:00 UTC: for every birthday event whose
 * month-day is today, it pushes "🎂 Today is <name>'s birthday — say hi!" to the
 * other members of each shared squad, via the squad-push gateway (mute +
 * notification-pref + quiet-hours respected). Deduped per recipient per birthday
 * per year via users/{uid}/birthdayNotificationsSentAt/{YYYY_ownerUid}.
 */
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {db} from "./shared";
import {sendSquadPush} from "./social";

const FieldValue = admin.firestore.FieldValue;

export const scheduledBirthdayCheck = onSchedule("0 9 * * *", async () => {
  const now = new Date();
  const month = now.getUTCMonth() + 1;
  const day = now.getUTCDate();
  const year = now.getUTCFullYear();

  // collectionGroup on a single field uses the automatic index; filter the
  // month/day in code to avoid a composite index.
  const events = await db.collectionGroup("goalsVisible").where("subtype", "==", "birthday").get();
  const todays = events.docs.filter((e) => e.get("month") === month && e.get("day") === day);

  for (const ev of todays) {
    const ownerUid = ev.get("ownerUid") as string | undefined;
    if (!ownerUid) continue;
    const displayName = (ev.get("displayName") as string | undefined) ?? "A squadmate";
    const squadIds = (ev.get("squadIds") as string[] | undefined) ?? [];

    for (const squadId of squadIds) {
      const squad = await db.doc(`squads/${squadId}`).get();
      if (!squad.exists) continue;
      const members = (squad.get("memberUids") as string[] | undefined) ?? [];
      const others = members.filter((m) => m !== ownerUid);

      // One push per recipient per birthday per year.
      const recipients: string[] = [];
      for (const r of others) {
        const marker = db.doc(`users/${r}/birthdayNotificationsSentAt/${year}_${ownerUid}`);
        const fresh = await db.runTransaction(async (tx) => {
          const s = await tx.get(marker);
          if (s.exists) return false;
          tx.set(marker, {at: FieldValue.serverTimestamp(), ownerUid, squadId});
          return true;
        });
        if (fresh) recipients.push(r);
      }
      if (recipients.length > 0) {
        await sendSquadPush(
          squadId,
          recipients,
          {title: "🎂 Birthday", body: `Today is ${displayName}'s birthday — say hi!`},
          {pref: "squadAttributed", now},
        );
      }
    }
  }
  console.log(`scheduledBirthdayCheck: ${todays.length} birthday event(s) today`);
});
