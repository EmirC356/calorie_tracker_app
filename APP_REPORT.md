# Calorie Tracker + Squad Accountability — Feature & Architecture Report

_A Flutter calorie/exercise/weight tracker with an AI meal/exercise estimator
and a cloud-synced "Squad Accountability" social layer._

---

## 1. Overview & guiding principle

The app is **local-first**. Everything you log — meals, exercises, body weight,
meal preps — lives in an on-device SQLite database and works fully offline.

The **Squad** feature is the only cloud-synced component. Even then, **only
daily *aggregated* snapshots** (your status and, optionally, totals) leave the
device — never your raw meals or exercises. What a squad can see about you is
controlled per-squad by a privacy/sharing level you choose.

- **Package id:** `com.emirceylan.calorietracker`
- **Firebase project:** `riwex-d01aa` (Blaze plan)
- **Primary test device:** Samsung A55 (Android 15); second account via a
  Pixel 9a emulator.

---

## 2. Tech stack

| Area | Choice |
|------|--------|
| Framework | Flutter (Dart SDK ^3.9.2), Material 3 |
| State management | `provider` (ChangeNotifier) |
| Local database | `sqflite` (+ `path`, `path_provider`) |
| Local key/value | `shared_preferences` (Gemini key, user profile) |
| Charts | `fl_chart` |
| HTTP | `http` (used to call Gemini's REST API directly) |
| AI | **Google Gemini `gemini-2.5-flash`** via REST (not the `google_generative_ai` package) |
| Auth | `firebase_auth` + `google_sign_in` (Google sign-in only) |
| Cloud DB | `cloud_firestore` |
| Push | `firebase_messaging` (FCM) |
| Serverless | Cloud Functions (TypeScript, 2nd gen) on Blaze |
| Min Android SDK | 23 (required by Firebase Auth/Firestore) |

---

## 3. Project structure

```
lib/
  main.dart                 # bootstrap: Firebase init, providers, theme
  theme/app_theme.dart      # "furnace" palette + neon helpers
  data/
    food_database.dart      # built-in foods (protein/carb/veggie/oil/alcohol)
    met_table.dart          # MET values + intensity factor for exercise calc
  models/                   # plain Dart models + pure logic (index.dart re-exports)
  services/                 # IO/integration: db, ai, auth, squad, snapshot, notifications
  providers/                # ChangeNotifiers bridging services <-> UI
  screens/                  # one screen per file; screens/squad/ for the squad UI
  widgets/                  # reusable UI (edit sheets, charts, squad widgets)
firebase/
  firestore.rules           # security rules (emulator-tested)
  firestore.indexes.json
  functions/                # Cloud Functions (TypeScript)
  test/rules.test.mjs       # @firebase/rules-unit-testing suite (16 checks)
test/                       # Dart unit + widget tests (63)
```

Layering is strict: **screens → providers → services → models**. Screens never
touch Firestore/SQLite directly; they go through a provider, which calls a
service, which maps to/from models.

---

## 4. Local features (work offline, no account)

### 4.1 Meal logging — two modes
- **QUICK (AI):** type a meal in plain language ("chicken shawarma wrap with
  fries") → Gemini returns estimated calories + macros.
- **DETAILED (grams):** pick foods from the built-in database by category
  (protein / carbs / veggies) with gram amounts, plus olive-oil spray count and
  alcohol — totals computed locally for accuracy.
- **Load from Meal Prep:** pull a saved prep into the detailed form (portions
  divided by the prep's meal count).

### 4.2 Meal prep
Build a batch meal, set how many meals it makes, and track remaining servings
with a portion-dot grid. Logging a meal from a prep consumes one serving.

### 4.3 Exercise logging
- **MET quick-pick:** choose an activity from a built-in MET table; calories =
  `MET × bodyweight(kg) × hours`, **scaled by intensity** (low ×0.85 / medium
  ×1.0 / high ×1.2).
- **AI estimate:** for any free-text activity, Gemini estimates calories burned
  from name + duration + intensity + body weight.
- Body weight is taken from your latest logged weight, falling back to your
  profile weight, then a 70 kg default. Manual override always allowed.

### 4.4 Body weight tracking
Log weight with an "empty stomach" flag; line chart distinguishes normal vs
empty-stomach entries; history list.

### 4.5 Dashboard
- **Consumed / target progress bars** for calories and protein (targets from
  your profile; see 4.6), plus calories burned and net.
- **Charts** (collapsible): 90-day weight line with a 7-day moving average,
  14-day calories bar chart with a goal line, and a donut of today's
  protein/carb/fat split.
- Quick-action buttons and links to logs.

### 4.6 Profile & goals (TDEE)
Enter height, age, sex, activity level, and goal (cut/maintain/bulk). The app
computes **BMR via Mifflin–St Jeor**, applies an activity factor for **TDEE**,
and derives a daily **calorie target** (cut −500 / maintain / bulk +300) and a
**protein target** (goal-based g/kg). Persisted via `shared_preferences`.

### 4.7 Edit & delete
Long-press any meal or exercise card → bottom sheet with **Edit** / **Delete**
(shared widget used on the dashboard, fitness tab, and both log screens).

### 4.8 Meal advisor
A Gemini chat screen for free-form nutrition/meal-prep questions.

### 4.9 Settings
Enter/replace the Gemini API key (shown masked, with a Clear button). Persisted
and restored on cold start.

---

## 5. Squad Accountability (cloud)

A squad is up to **10 friends**. Each member sets their **own** daily goal and
their **own** privacy level for that squad. Built in 8 shippable phases.

### 5.1 Auth & profile (Phase 1)
Google sign-in only; the rest of the app is usable signed out — only the Squad
tab requires an account. First sign-in prompts for a display name (default: the
Google name) and uses the Google avatar; saved to `users/{uid}`.

### 5.2 Create / join squads (Phase 2)
- Create a squad → get a **6-digit invite code** (valid 7 days; owner can
  regenerate, instantly disabling the old one).
- Join by code; membership capped at 10 (enforced in rules).

### 5.3 Goals, sharing & settings (Phase 3)
- **Goal** (any combination, ≥1 required): calorie **cap** (≤) or **floor** (≥),
  **min exercise minutes**, **min calories burned**.
- **Sharing level** (per squad): `status` (just hit/in-progress/missed),
  `totals` (+ consumed/burned/minutes), `full` (+ meal & exercise lists). Your
  configured *goal* is always visible; only the *detail* is gated.
- **Settings tab:** edit goal, edit sharing, mute notifications, leave squad;
  owners can rename, regenerate the code, kick members, transfer ownership, and
  **delete the squad**.

### 5.4 Daily snapshot + Today tab (Phase 4)
A background aggregator reads today's local SQLite data, computes your **status
per squad** (using that squad's goal), redacts fields by your sharing level, and
writes `squads/{id}/days/{date}/entries/{uid}`. The **Today** tab shows a grid
of member cards (avatar, goal, progress ring, status badge); tapping opens a
detail view limited to what their sharing level allows.

### 5.5 Reactions → nudges (Phase 5, reworked)
Tap 🔥 / 💪 / 👏 to **nudge** a squadmate. The latest emoji they received shows
next to their name on the Today cards. Nudges are **rate-limited** per
sender→recipient (currently 5s for testing; intended 5 min) and you **can't
nudge yourself** (enforced in UI and rules).

### 5.6 Leaderboard & streaks (Phase 6)
The **Board** tab ranks members by current streak, then weekly hits: **days hit
in the last 7**, **current streak** (survives an unlogged today), and **longest
streak** over a 30-day window.

### 5.7 Push notifications (Phase 7)
Cloud Functions send FCM pushes:
- when a member's status flips to **hit** ("X hit their goal");
- when someone **nudges** you (the emoji);
- a **22:00 local** per-squad end-of-day summary ("X of Y hit their goals").
Per-squad **mute** is honored. Foreground messages show as an in-app banner;
backgrounded/terminated show in the system tray.

### 5.8 30-day prune (Phase 8)
A daily scheduled function deletes `days/{date}` buckets older than 30 days
across all squads.

---

## 6. Architecture & data flow

### 6.1 Services
- **`database_service.dart`** — sqflite CRUD for meals/exercises/preps/weight;
  schema migrations; JSON backup safety net.
- **`ai_service.dart`** — Gemini REST calls (`analyzeFoodText`,
  `estimateCaloriesBurned`, `getMealAdvice`); key persistence.
- **`auth_service.dart`** — wraps `firebase_auth` + `google_sign_in`.
- **`squad_service.dart`** — *all* Firestore reads/writes for the squad feature.
- **`snapshot_service.dart`** — aggregates local data → redacts → uploads.
- **`notification_service.dart`** — FCM permission, token management, foreground
  handling.
- **`prefs.dart` / `invite_code.dart`** — small shared helpers.

### 6.2 Providers
`MealProvider`, `ExerciseProvider`, `WeightProvider`, `MealPrepProvider`,
`ProfileProvider`, `AuthProvider`, `SquadProvider`, `SnapshotProvider`. The
squad/auth/snapshot providers are created lazily so a Firebase issue can never
break the offline-only tabs.

### 6.3 Local data model (SQLite, schema v4)
Tables: `meals` (name, **portion_grams**, nutrients JSON, timestamp, notes),
`exercises`, `meal_preps`, `weight_entries`.
- **Migrations are additive** (never drop user data). The pattern: bump
  `_dbVersion`, add an `if (oldVersion < N)` block. v2 added prep + weight
  tables; v3 added `timestamp` indexes; v4 renamed `weight → portion_grams`
  (add column + copy, legacy column retained).
- A best-effort **`backupToJson()`** dumps tables to a file before any
  row-rewriting migration.
- Day queries use `timestamp >= start AND timestamp < startOfNextDay` (so the
  last second of a day isn't dropped) and are indexed.

### 6.4 Cloud data model (Firestore)
```
users/{uid}                       displayName, photoURL, fcmTokens[], tzOffsetMinutes, createdAt
squadCodes/{code}                 squadId, expiresAt          # invite-code lookup
squads/{squadId}                  name, ownerUid, memberUids[<=10], inviteCode, inviteCodeExpiresAt, createdAt
  members/{uid}                   goal, sharingLevel, displayName, photoURL, muted, joinedAt
  days/{YYYY-MM-DD}/entries/{uid} status (+consumed/burned/exerciseMinutes if totals; +meals/exercises if full), updatedAt
  days/{YYYY-MM-DD}/reactions/{id} fromUid, fromName, toUid, emoji, createdAt
```
**Denormalization:** `displayName`/`photoURL` are copied onto member docs and
`fromName` onto reactions, because the security rules make a user's `users` doc
**self-readable only** — squadmates can't read each other's profile docs, so
the names/avatars needed for the UI are stored where members *can* read them.

**The `squadCodes` lookup** exists because squad docs are member-only: a
non-member can't read a squad to find it by code, so they read
`squadCodes/{code}` (get-only) to resolve the squad id, then do a rule-validated
`arrayUnion` self-join.

### 6.5 Security rules (`firebase/firestore.rules`)
- `users/{uid}`: read/write your own only.
- `squads/{id}`: **read only if you're in `memberUids`**; create only as
  owner+sole-member; update only by the owner **or** a self-join (add only
  yourself, code not expired, ≤10) **or** a self-leave (remove only yourself,
  non-owner); delete only by the owner.
- `members/{uid}`: write only your own; `sharingLevel` constrained to the enum.
- `days/.../entries/{uid}`: write only your own; read if a member.
- `reactions`: create only with `fromUid == you` and `toUid != you`
  (no self-nudge); delete only your own; immutable.
- Verified with an **emulator test suite (16 checks)** before deploying — e.g.
  a non-member cannot read squad docs, the "my squads" list query is allowed,
  and self-nudge is rejected.
- _Subtlety:_ the squads read rule inlines `request.auth.uid` (not a helper
  function) so Firestore's query analyzer can match it against the
  `memberUids array-contains` filter for the list query.

### 6.6 Snapshot pipeline & privacy
`SnapshotProvider` triggers `SnapshotService.pushForUser` on: app **foreground**,
any **meal/exercise/weight change** (debounced 3s), a **5-minute timer**, and
**day rollover** (finalizes yesterday once). For each squad, it evaluates the
status against *that squad's* goal and writes an entry containing **only** the
fields the sharing level allows (`buildEntry`, unit-tested). Date keys use the
**local timezone** (a 1 a.m. meal counts toward that day).

### 6.7 Goal evaluation
Pure function (`SquadGoal.evaluate`): all active sub-goals must pass → `hit`;
otherwise `inProgress` while the day isn't over, else `missed`. An empty goal is
never "hit". Unit-tested across cap/floor/exercise/burned combinations.

### 6.8 Nudge cooldown
Tracked **locally with the device clock** in `SquadProvider` (not the Firestore
server timestamp) — comparing a server timestamp to `DateTime.now()` could get
stuck under clock skew, which previously caused a cooldown loop.

### 6.9 Cloud Functions (`firebase/functions`, TypeScript, 2nd gen)
- `onEntryStatusHit` — Firestore trigger; pushes when status transitions into
  `hit`.
- `onReactionCreated` — pushes the emoji to the nudged user.
- `scheduledSummary` — hourly; sends each user their per-squad summary at their
  local 22:00 (via `tzOffsetMinutes`).
- `pruneOldDays` — daily; `recursiveDelete` of day buckets older than 30 days.
All skip recipients who muted that squad. Server-side because the rules only let
a user delete their *own* docs — a client can't prune a whole day bucket.

---

## 7. AI integration details
- Endpoint: `generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`.
- For structured calls, `responseMimeType: application/json` and
  **`thinkingConfig.thinkingBudget = 0`** — `gemini-2.5-flash` is a thinking
  model and reasoning tokens otherwise eat the output budget, returning empty
  JSON.
- The API key is entered in Settings and persisted; for device installs it can
  be seeded once via `--dart-define=GEMINI_KEY=...`.

---

## 8. Theming & design
A dark **"furnace"** palette: near-black neutral base (`#0C0C0D`), a scarlet red
primary (`#E5342E`, matching the flame app icon), white + grays for hierarchy,
and a **navy** accent reserved for the Squad section. Helpers (`neonBox`,
`neonLabel`, `textGlow`) give the subtle glow look. App icon is the flame logo.

---

## 9. Testing
- **63 Dart tests** (unit + widget): meal/profile/user serialization, TDEE math,
  daily-calorie bucketing, snapshot redaction by sharing level, goal evaluation,
  streak computation, invite-code generation, squad create/join/leave/kick/
  transfer/delete, reactions + cooldown helpers, MET calc, and the GoalSummary
  widget.
- **16 Firestore rules checks** via `@firebase/rules-unit-testing` against the
  emulator (`cd firebase && npm run test:rules`; needs JDK 21+).

---

## 10. Build, run, deploy
- **Run/build (Android):** `flutter build apk --debug --dart-define=GEMINI_KEY=...`
  then `adb install -r`. (App id `com.emirceylan.calorietracker` installs
  separately from any old `com.example` build.)
- **Firestore rules:** paste `firebase/firestore.rules` in the console, or
  `firebase deploy --only firestore:rules`.
- **Functions (Blaze):** `cd firebase && firebase login && firebase use
  riwex-d01aa && firebase deploy --only functions`.
- Google sign-in requires the **debug SHA-1** registered in the Firebase Android
  app.

---

## 11. Known limitations & future work
- **Notifications need the functions deployed**; foreground uses an in-app
  banner (no `flutter_local_notifications` yet — a possible add for tray
  notifications while foregrounded).
- **Nudge cooldown is in-memory** (resets on app restart) and currently 5s for
  testing — set `kReactionCooldown` to 5 minutes for production.
- **Leaderboard reads 30 day-buckets per open** (fine at this scale; could be
  precomputed onto member docs later).
- Cloud Functions run on **Node 20**, which Google has flagged as deprecated —
  worth bumping to Node 22 + latest `firebase-functions`.
- Distribution to friends not yet set up (release signing + Firebase App
  Distribution); decide whether to ship a shared Gemini key or have each user
  enter their own.
- Name changes after joining a squad don't yet propagate to existing member
  docs (denormalized at join time).
```
