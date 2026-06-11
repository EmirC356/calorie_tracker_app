# Notification budget audit (Squad accountability sprint)

Target (sprint cross-cutting A): **≤ ~3 squad-attributed pushes per user per day on
average**, with a hard ceiling well under "spammy". Every squad push first passes
through `sendSquadPush`, which drops it if the recipient muted that squad, has the
relevant `notificationPrefs/master` bool off, or is in their quiet-hours window.

## Worst-case day — heavily-active 6-member squad (you + 5)

| Source | Max/day to one user | Notes / mitigation |
|---|---|---|
| Goal-hit ("X hit their goal", pre-existing `onEntryStatusHit`) | 5 | one per *other* member, once per day (status→hit transition only) |
| Streak-broken broadcast (#5) | ~1 | only fires for streaks **≥ 5**; rare; 1 per broken streak/squad |
| Full-squad day (#11) | 1 | once per day, marker-guarded |
| Ghost broadcast (#6) | ~1 | only after 72h silence; per ghosted member |
| Pause announce (#1) | ~1 | per pause/return event; rare |
| **Per-day comments (#10)** | **up to 25** | 5/sender × 5 senders — **the dominant risk** |
| Weekly retro (#12) | 0 (1×/week) | not a daily push |
| Streak at-risk warning (#4) | 1 | **local** notification, not squad-attributed; not in this budget |

**Uncollapsed worst case ≈ 34/day**, entirely dominated by comments. Everything
else sums to ~9 and is realistically 2–4 on a normal day.

## Mitigations in place

- `sendSquadPush` is the single FCM gate (mute + master-pref + quiet-hours).
- Multi-squad / multi-event pushes are collapsed into one where the spec allows
  (e.g. the at-risk warning names up to 3 squads in **one** message).
- Full-squad + streak-loss are idempotent (marker / `streakLossBroadcastAt`), so
  re-triggers don't double-send.
- Retro is 1/week and quiet-hours-deferrable to 08:00.

## The one remaining piece — comment push throttle (REQUIRED for the budget)

The comment **write path + ≤5/pair/day rate limit** ships (rules + client). The
**push** for a comment ("Emir commented on your day…") with the spec's **1 push
per 30 min per (recipient, sender)** throttle is a Cloud Function
(`onCommentCreated`) that is **not yet written** (the CF batch covered streak-loss
/ ghost / full-squad / retro). Until it lands, comment pushes would blow the
budget, so:

- **Recommended:** add `onCommentCreated` that, per (recipient, sender), sends at
  most one push every 30 min and batches the rest into the next one — collapsing
  the 25 worst-case comment pushes down to ≤ ~2/sender/day → **≤ ~10 even in the
  pathological case, ~1–2 typical.** With it, the realistic daily total lands at
  **~3**, on target.
- Interim: comment pushes are simply not sent yet (only the in-app thread
  updates), so the live budget today is **~2–4/day** — already within target.

## Verdict

With comment pushes gated behind the (pending) 30-min throttle CF, the squad
push budget holds at **~3/day average**. The only action item to "declare done"
on the budget is wiring `onCommentCreated` with that throttle before comment
pushes are enabled.
