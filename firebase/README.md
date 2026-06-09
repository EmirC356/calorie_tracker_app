# Firebase (Squad Accountability)

Cloud backend for the Squad feature. **Only daily aggregated snapshots are
synced** — raw meals/exercises/weight never leave the device.

- Project: `riwex-d01aa`
- Android app id: `com.emirceylan.calorietracker`
- Plan: Blaze (required for Cloud Functions in Phase 7; ~free at this scale)

## Deploying Firestore rules

The security rules live in [`firestore.rules`](./firestore.rules).

**Option A — Firebase console (quickest):**
1. Firebase console → Firestore Database → **Rules** tab.
2. Paste the contents of `firestore.rules`.
3. **Publish**.

**Option B — Firebase CLI:**
```bash
npm i -g firebase-tools
firebase login
firebase use riwex-d01aa
firebase deploy --only firestore:rules
```
(Requires a `firebase.json` pointing at `firestore.rules`; added when the CLI
project is initialised.)

## Phase status
- **Phase 1 (done):** `users/{uid}` rules — each user reads/writes only their own
  profile. Publish these so Google sign-in can persist the profile.
- Phase 2+: squad / member / day-entry / reaction rules, Cloud Functions
  (FCM + nightly summary + 30-day prune). Documented as they land.
