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

## Testing the rules (emulator)

Verifies the security rules — most importantly that a **non-member cannot read
squad docs** — without touching live Firebase:

```bash
cd firebase
npm install
npm run test:rules    # = firebase emulators:exec --only firestore "node test/rules.test.mjs"
```

Requirements: **JDK 21+ on PATH** (firebase-tools rejects older Java — if you
have an old Oracle Java 8 shim first on PATH, put a 21 JDK ahead of it, e.g.
Android Studio's `jbr`). Uses a `demo-` project id so no `firebase login` is
needed. Last run: **9/9 passing**.

## Indexes

`firestore.indexes.json` holds the composite index for the "my squads" query
(`memberUids` array-contains + `createdAt` desc). Deploy via
`firebase deploy --only firestore:indexes`, or click the link Firestore prints
in logcat the first time the query runs.

## Cloud Functions (notifications) — Phase 7

TypeScript functions in [`functions/`](./functions) (2nd gen, requires Blaze):
- `onEntryStatusHit` — pushes "{name} hit their goal" to other members when a
  day status transitions to `hit`.
- `onReactionCreated` — pushes the emoji to the nudged member.
- `scheduledSummary` — hourly; at each user's local 22:00 sends a per-squad
  "X of Y squadmates hit their goals today". (Local time via the user doc's
  `tzOffsetMinutes`, written by the app.)

Recipients with `members/{uid}.muted == true` are skipped.

**Deploy (one-time setup, then redeploy on changes):**
```bash
npm i -g firebase-tools            # if not installed
cd firebase
firebase login                     # interactive (browser)
firebase use riwex-d01aa
firebase deploy --only functions   # builds via predeploy, then deploys
```
First functions deploy enables required Google APIs (Cloud Build, Artifact
Registry) — accept the prompts. Test on a **physical device** (emulator FCM
delivery is unreliable). `cd functions && npm run build` type-checks locally
without deploying.

## Phase status
- **Phase 1 (done):** `users/{uid}` rules — each user reads/writes only their own
  profile. Publish these so Google sign-in can persist the profile.
- Phase 2+: squad / member / day-entry / reaction rules, Cloud Functions
  (FCM + nightly summary + 30-day prune). Documented as they land.
