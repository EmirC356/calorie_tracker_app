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

---

## 12. Goals & Calendar

A calendar-based goal planner with streaks, layered on the same local-first
architecture. The bottom nav is **3 tabs — Squads · Health · Calendar**. The
**Health** tab is a shell with a sub-TabBar (Dashboard · Meals · Fitness ·
Weight · Advisor) that contains every old local-only screen; the **Calendar**
tab is the Goals surface, accented **amber** (`#F5A524`) to distinguish it from
the red primary and the navy Squad accent.

### 12.1 Goal types
- **Manual** — checked off by hand (done / failed / skipped).
- **Tracked** — auto-evaluated against existing app data. Metrics: `kcalTotal`,
  `proteinG`, `exerciseMinutes`, `exerciseSessionCount` (sessions ≥ a min
  duration, default 20), `weightDeltaKg` (latest − first in period), `waterMl`
  (future; never auto-fails until water logging ships). Each has a comparator
  (≤ cap / ≥ floor), a target, and a period (day or week).

### 12.2 Local data model (SQLite, schema v5)
Additive migration only: `_dbVersion` 4 → 5, an `if (oldVersion < 5)` block adds
three tables, no existing rows touched. `PRAGMA foreign_keys = ON`
(`onConfigure`) so the occurrences → goals `ON DELETE CASCADE` fires.
- `goals` — the reusable definition ("ticket"): title/description, category
  (+ custom label), color (ARGB int), priority, type, the tracked fields,
  schedule (start_date as `YYYY-MM-DD`, time_of_day `HH:mm`, recurrence_json,
  end_date_days_from_start), squad_visible, reminder_minutes_before,
  morning_brief_included, created_at (UTC), archived.
- `goal_occurrences` — materialized instances: (goal_id, occurrence_date)
  unique, status, done_at, override_flag, period_value_cached, notes.
- `goal_suggestions` — inbound squad suggestions (local mirror).

Dates that are calendar dates (start, occurrence) are stored as `YYYY-MM-DD` so
they never drift across timezones and match the cloud occurrenceId scheme;
true timestamps (createdAt, doneAt) are stored UTC.

**Two naming decisions:** the occurrence-status enum is **`OccurrenceStatus`**
(`open/done/failed/skipped`) to avoid colliding with the Squad feature's existing
`GoalStatus` (`hit/inProgress/missed`); and the TDEE diet enum `Goal`
(`cut/maintain/bulk`) was renamed **`DietGoal`** (value names unchanged → JSON
identical) so the new feature's central class can be `Goal`.

### 12.3 Recurrence engine + lazy materialization + sweep
- `RecurrenceEngine.occurrencesInRange(goal, from, to)` is the **source of
  truth** for which dates a goal lands on (none / daily / weekly-by-weekday /
  weekly-N-times / monthly day 1–28). **Week starts Monday.** A count-based
  weekly goal emits **one Monday anchor per ISO week** (the tracked evaluator
  counts the whole Mon–Sun week); a goal that starts mid-week first anchors the
  following Monday. Never emits a date before the start or after the series end.
  Capping monthly at day 28 guarantees every month (incl. February) has the day.
- **Materialization is lazy**: viewing the calendar calls the engine and writes
  nothing. Rows appear only on user interaction or the **end-of-period sweep**
  (`GoalSweepService.sweepFinalizePastOccurrences`), which finalizes occurrences
  whose period fully ended — manual → `failed`, tracked → the evaluator —
  skipping any that already have a row (so a user `done` is never overwritten).
  It's **idempotent** and backfill-bounded (default 90 days). The sweep runs from
  `GoalProvider` (Calendar open / pull-to-refresh), bounded by a prefs-persisted
  last-sweep date — kept off the Firebase-gated snapshot pipeline so a cloud
  problem can't block goal finalization.

### 12.4 Evaluator
`GoalEvaluator.evaluate(...)` reads through narrow read-only ports
(`MealRepo`/`ExerciseRepo`/`WeightRepo`/`WaterRepo` in `services/repos/`), so
it's unit-tested with in-memory fakes. Pass rules: met → `done`; otherwise
`open` during the period, `failed` once it ends. Progress ring: floor =
`min(metric/target,1)·100`, cap = `clamp((target−metric)/target·100, 0, 100)`.

### 12.5 Calendar UI
Month / Week / Day views over a hand-rolled grid (no `table_calendar`). Each day
shows its goal chips (category color, priority dot, status icon) and activity
summary chips (`4 meals · 1820 kcal`, `1 ex · 30 min`, weight). Full goal CRUD
via a 13-field form; the detail sheet shows live tracked progress and the
mark-done/failed/skip/edit/delete actions. Recurring edits/deletes prompt
"only this / this and future / all in the series" (this-and-future truncates the
old series and starts a fresh one). **History** is a filterable occurrence list +
a per-category success-rate card with retroactive override (flips
`override_flag`, shown as an "edited" tag).

### 12.6 Cloud model & squad visibility
Only aggregate, non-private fields leave the device, gated by security rules:
- `users/{uid}/goalsVisible/{goalId}_{YYYY-MM-DD}` — written by the snapshot
  pipeline for squad-visible occurrences in `[today−7d, today+30d]` (a user
  override wins over the live evaluation), pruned when a goal is un-shared,
  archived, deleted, or falls out of the window.
  **Denormalization decision:** instead of a `sharedToSquadIds` array checked
  with a per-squad `get()` (a loop Firestore rules can't express), each doc
  carries **`readerUids`** — the union of memberUids across the owner's squads.
  The rule is then O(1) (`request.auth.uid in resource.data.readerUids`) and a
  squadmate reads with `where readerUids array-contains me` (uid inlined so the
  query analyzer matches, like the squads "my squads" rule). Trade-off:
  readerUids is recomputed each push, so a removed squadmate keeps read access
  only until the next push.
- `squads/{squadId}/suggestions/{id}` — a member proposes a goal to another
  member (status pending → accepted|rejected|expired, 7-day expiry). The inbox
  is a **collection-group** query (`toUid == me`, needs the composite index in
  `firestore.indexes.json`). Create requires `fromUid == self` and the recipient
  be a member; only the recipient can transition the status.

### 12.7 Cloud Functions (notification queues)
`functions/src/calendar.ts` (shared helpers in `shared.ts`):
- `onGoalSuggestionCreated` / `onGoalSuggestionAccepted` — suggestion-lifecycle
  pushes (honor per-squad mute).
- `scheduledMorningBrief` (every 15 min) — at each user's local 08:00, sends a
  brief from the device-written `users/{uid}/todaysGoalsBrief/{date}` doc; prunes
  briefs older than 7 days.
- `scheduledGoalReminders` (every 5 min) — fires any `pendingReminders/{occId}`
  doc whose `fireAt` has passed, then deletes it.

**Why a queue:** the heavy logic stays on the device (local SQLite is the truth);
the device writes `todaysGoalsBrief` + `pendingReminders` during the daily sweep
and Firestore acts as a queue, so the functions are simple readers + senders and
we never mirror every goal to the cloud. The brief + reminders are personal,
gated by a single user flag `goalNotificationsEnabled` (missing == on; toggle in
Health → Settings); both queue collections are owner-only (functions use the
admin SDK, which bypasses rules).

### 12.8 Testing
- **+~85 Dart tests**: models (Goal/recurrence/occurrence/suggestion round-trips,
  history aggregation, squadmate stats, examples), the recurrence engine, the
  sweep, the evaluator (every metric × cap/floor), DB CRUD + cascade + the v4→v5
  migration (via `sqflite_common_ffi`), the cloud suggestion + goalsVisible +
  notification-queue paths (via `fake_cloud_firestore`), and widgets (goal chip,
  day-summary chip, recurrence picker, history list, squadmate goals, goal
  inbox).
- **+16 Firestore rules checks** (now 32) for goalsVisible read gating,
  suggestion create/read/update authorization, and the owner-only queue
  collections.
- Functions `npm run build` (tsc) compiles clean.

### 12.9 Known limitations
- The rules tests require the Firestore emulator (firebase-tools needs **JDK
  21+**); run `cd firebase && npm run test:rules` on a JDK-21 machine.
- Cloud Functions for the Goals feature are written + build-checked but **not
  deployed** — deploy with `firebase deploy --only functions` (after a dryrun)
  once confirmed.
- A removed squadmate retains `goalsVisible` read access until the owner's next
  snapshot push refreshes `readerUids`.
