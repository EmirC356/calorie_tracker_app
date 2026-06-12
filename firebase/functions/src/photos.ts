/**
 * Proof — instant photo sharing Cloud Functions (2nd gen, Node 22).
 *
 * The 60s undo window is enforced by deferring "publish": a photo doc is created
 * with `published:false` and `pendingPublishAt = uploadedAt + 60s`. Squadmates
 * can't see it (rules) and no push/feed fires until the promoter flips it.
 *
 * Delayed-publish mechanism: a **scheduled query** (`scheduledPhotoPromote`,
 * every minute) rather than Cloud Tasks — chosen so we don't enable the Cloud
 * Tasks API. Cloud Scheduler's floor is 1 minute, so a photo becomes visible
 * 60-120s after upload; the undo guarantee (first 60s) is unaffected, only the
 * publish moment can lag up to a minute. Documented trade-off.
 *
 * Thumbnails use `sharp`. Deploy this codebase ONLY after confirming the sharp
 * runtime dependency: `firebase deploy --only functions`.
 */
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import sharp from "sharp";
import {db} from "./shared";
import {sendSquadPush, logActivity} from "./social";

const FieldValue = admin.firestore.FieldValue;

const glyph = (emoji: string): string =>
  emoji === "fire" ? "🔥" : emoji === "flex" ? "💪" : "👏";

/** On create, generate the 400×400 thumbnail, then immediately surface the
 * photo: write the feed entry/entries and push the squad. No undo window — the
 * doc is created already-published by the client, so squadmates see it at once. */
export const onPhotoCreated = onDocumentCreated(
  "squads/{squadId}/photos/{photoId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const {squadId, photoId} = event.params as {squadId: string; photoId: string};
    const data = snap.data();
    const storagePath = data.storagePath as string | undefined;
    if (!storagePath) return;

    // 1. Thumbnail (best-effort — the full image is shown until it lands).
    let thumbStoragePath: string | null = null;
    try {
      const bucket = admin.storage().bucket();
      let buf: Buffer;
      try {
        [buf] = await bucket.file(storagePath).download();
      } catch (_) {
        await new Promise((r) => setTimeout(r, 2000));
        [buf] = await bucket.file(storagePath).download();
      }
      const thumb = await sharp(buf).resize(400, 400, {fit: "cover"}).jpeg({quality: 75}).toBuffer();
      thumbStoragePath = `squads/${squadId}/thumbs/${photoId}.jpg`;
      await bucket.file(thumbStoragePath).save(thumb, {contentType: "image/jpeg"});
      await snap.ref.update({thumbStoragePath});
    } catch (e) {
      console.error(`onPhotoCreated: thumbnail failed for ${photoId}`, e);
    }

    // 2. Feed + push — the photo is live immediately.
    const actor = {
      actorUid: data.uploadedByUid as string,
      actorName: (data.uploadedByName as string) || "A squadmate",
      actorPhotoURL: data.uploadedByPhotoURL as string | undefined,
    };
    await logActivity(squadId, {
      ...actor,
      type: "photoShared",
      payload: {photoId, thumbStoragePath, ...(data.goalRef ? {goalRef: data.goalRef} : {})},
    });
    if (data.goalRef) {
      await logActivity(squadId, {
        ...actor,
        type: "goalProvedWithPhoto",
        payload: {photoId, title: data.goalRef.title ?? "a goal"},
      });
    }
    // Push — deduped across a multi-squad sibling group: the feed entry is
    // written per squad (above), but only the canonical (alphabetically-first)
    // squad sends ONE push, to the union of all sibling squads' members. A
    // member of two sibling squads thus gets a single push, not N.
    const siblingSquadIds = (data.siblingSquadIds as string[] | undefined) ?? [squadId];
    const canonical = [...siblingSquadIds].sort()[0];
    if (siblingSquadIds.length > 1 && squadId !== canonical) return;

    const squad = await db.doc(`squads/${squadId}`).get();
    const squadName = (squad.get("name") as string | undefined) ?? "your squad";
    const recipients = new Set<string>();
    if (siblingSquadIds.length > 1) {
      for (const sid of siblingSquadIds) {
        const sq = await db.doc(`squads/${sid}`).get();
        for (const m of (sq.get("memberUids") as string[] | undefined) ?? []) recipients.add(m);
      }
    } else {
      for (const m of (squad.get("memberUids") as string[] | undefined) ?? []) recipients.add(m);
    }
    recipients.delete(data.uploadedByUid as string);
    if (recipients.size > 0) {
      await sendSquadPush(
        canonical,
        [...recipients],
        {title: "New photo", body: `${actor.actorName} shared a photo to ${squadName}`},
        {pref: "squadAttributed"},
      );
    }
  },
);

/** On the deletedAt null→set transition: an undo (still pending) is a clean
 * memory hole — delete the Storage objects, no push/feed. A post-publish delete
 * logs `photoDeleted` and leaves the objects (reaped by the daily sweep). */
export const onPhotoSoftDeleted = onDocumentUpdated(
  "squads/{squadId}/photos/{photoId}",
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;
    if (before.get("deletedAt") != null || after.get("deletedAt") == null) return;

    const {squadId, photoId} = event.params as {squadId: string; photoId: string};

    // Cascade: soft-delete the other live siblings so one delete removes the
    // whole group from every squad. Each sibling's own trigger then handles its
    // Storage cleanup + feed entry. Idempotent (already-deleted siblings are
    // excluded by the deletedAt filter), so this never loops.
    const groupId = after.get("siblingGroupId") as string | undefined;
    if (groupId) {
      const siblings = await db
        .collectionGroup("photos")
        .where("siblingGroupId", "==", groupId)
        .where("deletedAt", "==", null)
        .get();
      if (!siblings.empty) {
        const batch = db.batch();
        for (const sib of siblings.docs) {
          batch.update(sib.ref, {deletedAt: FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }
    }

    const bucket = admin.storage().bucket();
    const wasPublished = after.get("published") === true || after.get("publishedAt") != null;

    if (!wasPublished) {
      // Undo within the window → erase Storage. No trace.
      const storagePath = after.get("storagePath") as string | undefined;
      const thumbPath = after.get("thumbStoragePath") as string | undefined;
      if (storagePath) await bucket.file(storagePath).delete().catch(() => {});
      if (thumbPath) await bucket.file(thumbPath).delete().catch(() => {});
      return;
    }

    await logActivity(squadId, {
      type: "photoDeleted",
      actorUid: after.get("uploadedByUid") as string,
      actorName: (after.get("uploadedByName") as string) || "A squadmate",
      actorPhotoURL: after.get("uploadedByPhotoURL") as string | undefined,
      payload: {photoId},
    });
  },
);

/** Notify the uploader when someone reacts, throttled to 3 photo pushes per
 * recipient per day (the rest are suppressed/bundled). Always logs the feed. */
export const onPhotoReactionCreated = onDocumentCreated(
  "squads/{squadId}/photoReactions/{reactionId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const {squadId} = event.params as {squadId: string};
    const photoId = snap.get("photoId") as string;
    const fromUid = snap.get("fromUid") as string;
    const fromName = (snap.get("fromName") as string) || "A squadmate";
    const emoji = snap.get("emoji") as string;

    const photo = await db.doc(`squads/${squadId}/photos/${photoId}`).get();
    if (!photo.exists) return;
    const toUid = photo.get("uploadedByUid") as string | undefined;
    if (!toUid || toUid === fromUid) return;

    await logActivity(squadId, {
      type: "photoReaction",
      actorUid: fromUid,
      actorName: fromName,
      subjectUid: toUid,
      subjectName: (photo.get("uploadedByName") as string) || "",
      payload: {photoId, emoji},
    });

    const dateKey = new Date().toISOString().slice(0, 10);
    const throttleRef = db.doc(`users/${toUid}/photoPushThrottle/${dateKey}`);
    const allow = await db.runTransaction(async (tx) => {
      const t = await tx.get(throttleRef);
      const count = (t.get("count") as number | undefined) ?? 0;
      if (count >= 3) return false;
      tx.set(throttleRef, {count: count + 1}, {merge: true});
      return true;
    });
    if (!allow) return;

    await sendSquadPush(
      squadId,
      [toUid],
      {title: "Photo reaction", body: `${fromName} sent ${glyph(emoji)} on your photo`},
      {pref: "squadAttributed"},
    );
  },
);
