import {onSchedule} from "firebase-functions/v2/scheduler";
import {db} from "./shared";

/**
 * Nightly trim of the activity feed: keeps the latest 100 events per squad and
 * deletes the rest. The feed is append-only (Cloud-Function writes), so this is
 * the only thing that bounds its growth.
 */
export const scheduledActivityPrune = onSchedule("every 24 hours", async () => {
  const squads = await db.collection("squads").get();
  let pruned = 0;
  for (const sq of squads.docs) {
    const extra = await db
      .collection(`squads/${sq.id}/activity`)
      .orderBy("createdAt", "desc")
      .offset(100)
      .get();
    for (const d of extra.docs) {
      await d.ref.delete();
      pruned++;
    }
  }
  console.log(`scheduledActivityPrune: removed ${pruned} activity event(s) beyond the 100 cap`);
});
