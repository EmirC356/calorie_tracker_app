# Design System — "Athletic Editorial on Dark"

Canonical reference for the Calorie Tracker design-system refactor. Every visual
decision in `lib/theme/`, `lib/widgets/ui/`, and the screen refactors derives
from this file. Do not re-derive tokens from screenshots, old code, or memory.

Aesthetic target: Whoop / Strava / Linear / Arc browser. Numbers are the design.
Restraint everywhere except where data lives. Section accents work as "rooms":
Blue for Squads, Red for Health, Amber for Calendar. Springs, not curves.
Haptics on meaningful actions. No glassmorphism, no skeuomorphic gradients, no
Lottie mascots.

---

## Surface ladder (dark, tonal — NO pure black, NO shadows on cards)

| Token | Hex | Use |
|---|---|---|
| surface0 | `#0A0A0B` | app background |
| surface1 | `#141416` | cards |
| surface2 | `#1C1C1F` | raised cards |
| surface3 | `#25252A` | sheets, dialogs, popovers |
| divider  | `#2A2A2F` | 1px hairlines only where structurally required |

## Text

| Token | Hex |
|---|---|
| textPrimary | `#F5F5F7` |
| textSecondary | `#A1A1A6` |
| textTertiary | `#6E6E73` |
| textDisabled | `#48484C` |

## Section accents (the "rooms")

| Token | Hex | Room |
|---|---|---|
| squadBlue | `#3B82F6` | Squads |
| healthRed | `#EF4444` | Health (alt `#E5342E` to match flame icon if visually preferred — pending device review) |
| calendarAmber | `#F59E0B` | Calendar |

Used ONLY for: focus borders, primary CTAs, active tab underlines, hero stat
color, progress fills, the section transition sweep. NOT for card backgrounds,
NOT for body text, NOT for icons by default.

## Status palette (orthogonal to sections, identical in every room)

| Token | Hex |
|---|---|
| statusHit | `#22C55E` |
| statusInProgress | `#F59E0B` |
| statusMissed | `#EF4444` |
| statusPaused | `#64748B` |

## Typography

- Display (large stat numbers, hero headers): **Space Grotesk** via google_fonts. Weights 500 / 700.
- Body / UI: **Inter** via google_fonts. Weights 400 / 500 / 600.
- ALL numeric text uses tabular numerals: `fontFeatures: [FontFeature.tabularFigures()]`.

Type scale (use these names everywhere):

| Name | Spec |
|---|---|
| displayXL | 56sp / Space Grotesk 700 / -0.5 letter-spacing — hero stats |
| displayL | 40sp / Space Grotesk 700 / -0.3 |
| displayM | 28sp / Space Grotesk 600 / -0.2 |
| titleL | 22sp / Inter 600 |
| titleM | 17sp / Inter 600 |
| bodyL | 16sp / Inter 400 |
| bodyM | 14sp / Inter 400 |
| bodyS | 13sp / Inter 500 / +0.3 letter-spacing (labels and chips) |
| caption | 11sp / Inter 500 / +0.5 letter-spacing / UPPERCASE |

## Spacing scale

4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 / 64. No arbitrary paddings outside this list.

## Radius scale

0 (data lines) · 8 (chips, small buttons) · 12 (cards) · 16 (sheets) · 999 (pills, avatars).

## Border / focus rules

- Cards have NO borders by default. Depth comes from the surface ladder.
- Active / focused / selected: 1.5px border in section accent + accent glow at
  18% alpha (BoxShadow blur 12, alpha 0.18). NO solid color fills on focus.
- Destructive states: 1.5px statusMissed border, never red card backgrounds.

## Icons

- `lucide_icons` package. Stroke width 1.5. Filled variant for active tabs,
  line variant for inactive.
- No emoji as nav icons. Emoji allowed ONLY in celebration moments (flame,
  party, muscle).

## Motion

- Default curve: spring (`SpringSimulation` via
  `SpringDescription(mass: 1, stiffness: 320, damping: 26)`). Never `Curves.easeInOut`.
- Non-spring transitions: 220ms enter, 160ms exit.
- Page route: shared-element via Hero for card-to-detail navigation. NO default
  MaterialPageRoute slide.
- Number changes: `TweenAnimationBuilder<double>` over 600ms with easeOutCubic —
  the "ticker" effect.
- Progress fills: 800ms spring with slight overshoot.
- Choreography: stagger reveals 50–80ms between siblings (header → hero stat →
  cards → list). `flutter_staggered_animations` patterns or hand-rolled
  `AnimatedSlide` + `AnimatedOpacity`.
- Haptics: `HapticFeedback.lightImpact` on taps, `mediumImpact` on goal-hit
  moments, `heavyImpact` on streak-broken broadcasts.

## Dependencies (the only approved additions)

google_fonts · lucide_icons · flutter_staggered_animations · shimmer

## Inspirations (visual reference only — channel principles, never clone)

Whoop (data-as-hero) · Strava (athletic editorial) · Linear (dark surface
craft) · Arc browser (color as room) · Robinhood pre-redesign (tabular
numerals + negative space).

---

## Token files

| File | Contents |
|---|---|
| `lib/theme/app_colors.dart` | `AppColors` — every color above |
| `lib/theme/app_text_styles.dart` | `AppText` — the type scale |
| `lib/theme/app_spacing.dart` | `Spacing.s4 … s64`, `AppRadius` |
| `lib/theme/app_motion.dart` | `AppMotion` — springs, durations, glow helper |
| `lib/theme/app_theme.dart` | `buildAppTheme()` + deprecated furnace aliases |

Legacy `furnace` identifiers (`kBg`, `kRed`, `kNavy`, `kAmber`, `kCard`, …)
remain as deprecated aliases in `app_theme.dart` delegating to `AppColors`.
New code uses `AppColors` / `AppText` / `Spacing` / `AppMotion` only.

---

## Screen inventory (`lib/screens/`)

| File | Description |
|---|---|
| `home_screen.dart` | Root scaffold; 3-tab bottom nav (Squads · Health · Calendar) |
| `index.dart` | Barrel re-exports for screens |
| `log_meal_screen.dart` | Meal entry: QUICK (AI text) / DETAILED (grams) modes + load-from-prep |
| `meal_analysis_screen.dart` | AI meal analysis result (calories + macros); has AI lock overlay |
| `meal_logs_screen.dart` | Historical meal list with edit/delete |
| `meal_prep_screen.dart` | Batch meal preps with portion-dot serving tracker |
| `meal_advice_screen.dart` | Gemini chat for nutrition questions |
| `exercise_logging_screen.dart` | Exercise entry: MET quick-pick + AI estimate |
| `exercise_logs_screen.dart` | Historical exercise list |
| `weight_tracker_screen.dart` | Body-weight log + line chart (empty-stomach flag) |
| `profile_screen.dart` | TDEE profile: height/age/sex/activity/goal → calorie + protein targets |
| `settings_screen.dart` | App settings (Gemini key entry, toggles) |
| `settings/api_key_screen.dart` | Dedicated API-key entry/management screen |
| `health/health_shell_screen.dart` | Health tab shell: sub-TabBar (Dashboard · Meals · Fitness · Weight · Advisor) |
| `health/dashboard_screen.dart` | Health dashboard: calorie/protein progress, charts, quick actions |
| `health/meals_tab_screen.dart` | Meals tab inside Health shell |
| `health/fitness_tab_screen.dart` | Fitness/exercise tab inside Health shell |
| `health/health_chips.dart` | Small summary chips used across Health screens |
| `squad/sign_in_screen.dart` | Google sign-in entry to Squad section |
| `squad/profile_setup_screen.dart` | First-run display-name prompt |
| `squad/squad_tab.dart` | Squad tab root: routes sign-in / list / home |
| `squad/squad_list_screen.dart` | List of user's squads + create/join CTAs |
| `squad/create_squad_screen.dart` | Create squad → invite code |
| `squad/join_squad_screen.dart` | Join squad by 6-digit code |
| `squad/squad_home_screen.dart` | Squad shell: Today / Board / Settings tabs |
| `squad/squad_today_tab.dart` | Today tab: member cards grid, reactions/nudges |
| `squad/squad_board_tab.dart` | Leaderboard: streaks, weekly hits |
| `squad/squad_settings_screen.dart` | Per-squad goal/sharing/mute/leave; owner admin |
| `squad/goal_editor_screen.dart` | Edit personal squad goal (cap/floor/exercise) |
| `squad/goal_suggest_screen.dart` | Propose a goal to a squadmate |
| `squad/goal_inbox_screen.dart` | Inbound goal suggestions (accept/reject) |
| `squad/member_day_detail_screen.dart` | Squadmate day detail (gated by sharing level) |
| `squad/squad_notifications_screen.dart` | Squad notification preferences/history |
| `calendar/calendar_screen.dart` | Calendar shell: Day / Week / Month segmented control |
| `calendar/calendar_day_view.dart` | Day view: goals + activity timeline |
| `calendar/calendar_week_view.dart` | Week view: 3-day swipeable columns |
| `calendar/calendar_month_view.dart` | Month grid: goal dots + summary chips |
| `calendar/goal_create_screen.dart` | Create goal (simplified + collapsible advanced) |
| `calendar/goal_edit_screen.dart` | Edit existing goal |
| `calendar/goal_form_screen.dart` | Shared goal form fields (13-field) |
| `calendar/goal_examples.dart` | Example/template goals for the create flow |
| `calendar/goal_history_screen.dart` | Occurrence history + per-category success rates |
| `calendar/recurring_edit_choice_sheet.dart` | "Only this / this and future / all" prompt |

## Widget inventory (`lib/widgets/`)

| File | Description |
|---|---|
| `dashboard_charts.dart` | fl_chart wrappers: 90-day weight line, 14-day calories bar, macro donut |
| `date_nav_bar.dart` | Prev/next day navigation bar |
| `edit_entry_sheets.dart` | Long-press edit/delete bottom sheets for meals/exercises |
| `undo_delete.dart` | Undo snackbar helper for deletions |
| `water_card.dart` | Water intake card |
| `ai/blocked_ai_overlay.dart` | Lock overlay when no Gemini key (DO NOT alter logic) |
| `calendar/calendar_status.dart` | Occurrence status icon/color mapping |
| `calendar/day_goal_row.dart` | Goal occurrence row in Day view (72dp treatment) |
| `calendar/day_summary_chip.dart` | "4 meals · 1820 kcal" summary chips |
| `calendar/goal_action_dialog.dart` | Centered goal action dialog (done/fail/skip/edit/delete) |
| `calendar/goal_chip.dart` | Goal chip: category color, priority dot, status icon |
| `calendar/progress_ring.dart` | Tracked-goal progress ring (calendar variant) |
| `squad/activity_feed.dart` | Squad activity feed list |
| `squad/checkin.dart` | Daily check-in widget |
| `squad/comment_thread.dart` | Comments on a member's day |
| `squad/goal_summary.dart` | Compact goal summary line (unit-tested) |
| `squad/group_goals_strip.dart` | Strip of squadmates' shared goals |
| `squad/intention_banner.dart` | Daily intention banner |
| `squad/member_card.dart` | Today-tab member card: avatar, ring, status badge |
| `squad/progress_ring.dart` | Member progress ring (squad variant) |
| `squad/reaction_bar.dart` | 🔥/💪/👏 nudge bar (rate-limited) |
| `squad/squadmate_goals.dart` | Squadmate goals list (visibility-gated) |
| `squad/squad_member_avatar.dart` | Avatar with streak-tier flame/ring treatment |
| `squad/squad_status.dart` | hit/inProgress/missed status badge |

New primitives land in `lib/widgets/ui/` (Phase 1): HeroStat, AnimatedRing,
AnimatedNumber, SectionAppBar, MemberAvatar, StatusPill, ColoredLeftBorderCard,
HeroTransitionScaffold, ShimmerPlaceholder, SectionSweep, SectionNav (Phase 2).
