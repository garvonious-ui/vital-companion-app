# Changelog — Vital Companion App

## 2026-03-31 — Session 10

### iOS 26 SDK Upgrade
- **Deployment target**: 17.0 → 26.0, **Xcode**: 16.0 → 26.0, **Swift**: 5.9 → 6.0
- **@Observable migration** — all 6 service classes (`AuthService`, `HealthKitService`, `SyncService`, `APIService`, `NetworkMonitor`, `MealAnalysisService`) converted from `ObservableObject` + `@Published` to `@Observable` macro
- **VitalApp.swift** — `@StateObject` → `@State`, `.environmentObject()` → `.environment()`
- **~25 view files** — `@EnvironmentObject var` → `@Environment(Type.self) var`
- **MealAnalysisView** — `@StateObject` → `@State`, `NavigationView` → `NavigationStack`
- **Swift 6 strict concurrency** — all model structs in AppModels.swift, HealthData.swift, MealAnalysisService.swift marked `Sendable`; `MetricConfig`/`RelatedMetricConfig` use `@unchecked Sendable` (KeyPath not Sendable)
- **HealthKitService** — added `@MainActor`, removed manual `MainActor.run` dispatch
- Build passes with zero errors on Swift 6

### Sleep Detail View (New)
- **HealthKitService** — added `querySleepStages()` (REM/Core/Deep/Awake durations, bed start/end times) and `querySleepHeartRate()` (HR samples during sleep window, avg/min/max)
- **SleepDetailView.swift** (new file) — sleep summary card (total time, bedtime/wake), sleep stages with animated horizontal bars, sleep HR chart (line + area mark with avg/min/max stats), 7-day sleep duration bar chart
- **TodayView** — sleep metric card now navigates to `SleepDetailView` instead of generic `MetricDetailView`
- Added `HKQuantityType(.heartRate)` to HealthKit read permissions (was missing — only had HRV and resting HR)

### Meal Scan Polish
- **Analyzing view** — pulsing photo with emerald border animation, rotating status messages ("Identifying food items..." → "Estimating portions..." → "Calculating macros..." → "Almost there...")
- **Haptics** — medium impact on photo capture, success on results, error on failure
- **Results view** — staggered fade-in animation on detected food items (0.08s delay per item)

### UX Changes
- **Removed workout quick action** from Today tab — only Log meal and Water remain (workout button redundant with Activity tab)
- **Settings** — Privacy Policy and Web Dashboard now open in-app via `SFSafariViewController` (dark themed) instead of leaving the app. Added Support mailto link.

### Bug Fixes
- **Double load on app launch** — TodayView loaded data, then sync completed and triggered a second loadData via onChange. Fixed with 3-second debounce on lastLoadTime. Also added `hasLaunched` flag in MainTabView so scenePhase `.active` handler doesn't fire on first launch (only on returning from background).
- **Privacy policy requires login** — web middleware redirected unauthenticated users from /privacy to /auth/login. Added `/privacy`, `/terms`, `/support` to public routes bypass. Deployed via git push.

### Files Created
- `Vital/Views/Today/SleepDetailView.swift`

### Files Modified (iOS — 35+ files)
- `project.yml` — iOS 26.0, Xcode 26.0, Swift 6.0
- `Vital/VitalApp.swift` — @State, .environment()
- `Vital/Services/AuthService.swift` — @Observable
- `Vital/Services/HealthKitService.swift` — @Observable, @MainActor, sleep stage/HR queries, heartRate read type
- `Vital/Services/SyncService.swift` — @Observable
- `Vital/Services/APIService.swift` — @Observable
- `Vital/Services/NetworkMonitor.swift` — @Observable
- `Vital/Services/MealAnalysisService.swift` — @Observable, Sendable models
- `Vital/Models/AppModels.swift` — Sendable on all structs, APIResponse generic constraint
- `Vital/Models/HealthData.swift` — Sendable on all structs
- `Vital/Views/ContentView.swift` — @Environment, hasLaunched flag
- `Vital/Views/Today/TodayView.swift` — @Environment, SleepDetailView nav, removed workout quick action, debounce fix
- `Vital/Views/Today/MetricDetailView.swift` — @unchecked Sendable on MetricConfig
- `Vital/Views/Nutrition/MealAnalysisView.swift` — @Environment/@State, NavigationStack, scan animations/haptics
- `Vital/Views/SettingsView.swift` — SafariViewController, support link
- ~20 additional view files — @EnvironmentObject → @Environment migration

### Files Modified (Web Dashboard)
- `src/middleware.ts` — public routes bypass for /privacy, /terms, /support

### Backend Deployments
- Middleware fix: deployed via git push (auto-deploy)

### Decisions
- Kept Swift strict concurrency enabled (no fallback to targeted mode) — all issues resolved
- Used `@unchecked Sendable` for MetricConfig (contains KeyPath which isn't Sendable, but struct is immutable)
- Sleep detail is a dedicated view, not added to generic MetricDetailView — allows richer stage/HR display
- Privacy policy stays on web (Apple requires public URL) but now accessible in-app via SafariViewController
- Support email is `lou@loucesario.com` (placeholder — needs dedicated address before launch)

### Status
- iOS 26 SDK: **Complete, builds clean on Swift 6**
- Sleep detail: **Complete, pending device test**
- Meal scan polish: **Complete**
- Double load fix: **Complete and tested**
- Privacy policy: **Publicly accessible, in-app viewer added**

### What's Next
1. **Test sleep detail on device** — verify stages and HR chart with real Apple Watch data
2. **App icon** — still needed
3. **App Store screenshots + description**
4. **Change support email** before launch
5. **Submit to App Store**

## 2026-03-30 — Session 9 (continued)

### Bug Fixes
- **HealthKit sync not running on app launch** — V2 redesign removed SyncStatusView from main flow, which was the only place `enableBackgroundDelivery()` was called. Added `.task` on MainTabView that enables background delivery + triggers initial sync, plus `scenePhase` handler that syncs when app returns to foreground
- **Pull-to-refresh "Network Error: cancelled"** — `onChange(syncService.isSyncing)` was triggering a second `loadData()` that cancelled the one from `syncAndRefresh()`. Removed duplicate call; onChange observer handles reload after sync
- **Resting HR not displaying** — Apple Watch writes resting HR samples with overnight startDate. Our query started from midnight today, missing them. Fixed by querying discrete metrics from 1 day earlier, and attributing the most recent resting HR sample to today's date

### AI Chat Context Expansion
- Added to metrics output: water_oz, SpO2, respiratory_rate, distance_miles, mood, energy
- Labs: now includes ALL results (not just flagged), grouped by status with draw dates
- Supplements: includes paused/stopped with notes and timing
- Added nutrition logs: last 7 days grouped by date with per-day macro totals
- Deployed to Vercel via git push

### Meal Photo Recognition — Session 1 (Backend + iOS Core)
- **POST /api/nutrition/analyze-meal** (Vercel) — receives base64 JPEG, calls Claude Sonnet vision to identify food items and estimate macros. Returns structured JSON with per-item breakdown, totals, confidence level. Supports Bearer token + cookie auth. Rate limited 20/day
- **MealAnalysisService.swift** — image compression (max 1024px, JPEG 0.8), API call, response parsing, meal type auto-detection by time of day
- **CameraPicker.swift** — UIViewControllerRepresentable wrapping UIImagePickerController for camera capture
- **MealAnalysisView.swift** — full scan flow: photo capture (camera or library via PhotosPicker), loading state with photo preview, results screen with editable meal name/type/macros, detected items list with per-item breakdown, confidence badge, save to nutrition_log
- **NutritionView.swift** — "+" button now shows action sheet: "Scan Meal Photo" / "Log Manually"
- Claude prompt follows spec: USDA-based estimates, portion detection via visual cues, rounds cal to 5/macros to 1g, handles non-food images

### Files Created
- `src/app/api/nutrition/analyze-meal/route.ts` (web dashboard)
- `Vital/Services/MealAnalysisService.swift`
- `Vital/Views/Nutrition/CameraPicker.swift`
- `Vital/Views/Nutrition/MealAnalysisView.swift`

### Files Modified
- `Vital/Views/ContentView.swift` — added syncService, scenePhase handler, enableBackgroundDelivery + sync on launch
- `Vital/Views/Today/TodayView.swift` — added syncService, onChange observer for sync completion, fixed syncAndRefresh
- `Vital/Services/SyncService.swift` — added debug logging ([Sync] prefixed prints)
- `Vital/Services/HealthKitService.swift` — discrete metrics query from 1 day earlier, resting HR attributed to today, debug logging
- `Vital/Views/Nutrition/NutritionView.swift` — added authService, scan option in "+" menu
- `src/lib/ai-context.ts` (web dashboard) — expanded to include all health data
- `docs/build-plan.md` — added Meal Photo Recognition section, bug fixes
- `docs/changelog.md` — this entry

### Meal Scan — Additional Fixes
- **NSCameraUsageDescription + NSPhotoLibraryUsageDescription** added to Info.plist (crash fix)
- **Save 500 error** — field names mismatched API; changed `meal_name`→`meal`, `meal_type`→`mealType`, `protein_g`→`proteinG`, etc.
- **3 entry points** — scan now available from Today "Log meal" quick action, Activity "Log meal" button, and NutritionView "+" button
- **Activity tab** — hid active plan card (user preference), recent workouts still visible

### Emerald Palette — Full Pass
- Replaced **287 hardcoded `Color(hex:)` references** across 23 files with `Brand.*` colors
- 7 agents ran in parallel fixing: MealFormView, QuickLogView, WorkoutDetailView, WorkoutsView, WorkoutSessionView, NutritionView, + 17 remaining files (components, settings, chat, login, permissions, labs, supplements, profile, dashboard, etc.)
- Refactored functions that took `UInt` color params to take `Color` directly (MetricDetailView, TodayView, LabsView, MoreView, SupplementsView, ProfileView, SettingsView)
- All views now consistent with Emerald Health palette

### Files Created
- `src/app/api/nutrition/analyze-meal/route.ts` (web dashboard)
- `Vital/Services/MealAnalysisService.swift`
- `Vital/Views/Nutrition/CameraPicker.swift`
- `Vital/Views/Nutrition/MealAnalysisView.swift`

### Files Modified (iOS)
- `Vital/Views/ContentView.swift` — syncService, scenePhase handler, sync on launch
- `Vital/Views/Today/TodayView.swift` — sync observer, meal scan entry point, Brand colors
- `Vital/Views/Activity/ActivityView.swift` — meal scan entry point, hid plan card, Brand colors
- `Vital/Views/Nutrition/NutritionView.swift` — scan option in "+" menu, Brand colors
- `Vital/Services/SyncService.swift` — debug logging
- `Vital/Services/HealthKitService.swift` — discrete metrics from 1 day earlier, resting HR fix, debug logging
- `Vital/Info.plist` — NSCameraUsageDescription, NSPhotoLibraryUsageDescription
- **23 view files** — full Brand.* color migration (see Emerald Palette section)

### Files Modified (Web Dashboard)
- `src/lib/ai-context.ts` — expanded to all health data (nutrition, water, SpO2, RR, all labs/supplements)
- `src/app/api/nutrition/analyze-meal/route.ts` — new endpoint

### Backend Deployments
- AI context expansion: auto-deployed via git push
- Meal analysis endpoint: force-deployed via `vercel --prod`

### Status
- Meal photo scan: **Complete and tested on device**
- Sync fixes: **Complete and tested**
- Resting HR: **Fixed and displaying**
- AI chat context: **Deployed with full data access**
- Emerald palette: **All 23 view files migrated**
- Active plan card: **Hidden per user preference**

### Onboarding Flow
- **AuthService.swift** — added `signUp(email:password:)` method using Supabase auth
- **LoginView.swift** — added "Create Account" / "Sign In" toggle with shared form
- **OnboardingView.swift** — 3-step wizard:
  - Step 1: Name, Sex, Date of Birth
  - Step 2: Height, Weight, Goals (multi-select FlowLayout)
  - Step 3: Daily targets (Calories, Protein, Steps, Water) with smart defaults
- **ContentView.swift** — after auth + HealthKit permissions, checks if profile exists (displayName != nil). If not → shows OnboardingView before MainTabView
- **POST /api/profile** — upserts profile row (Bearer + cookie auth)
- **POST /api/targets** — upserts targets row with defaults (Bearer + cookie auth)
- **project.yml** — added NSCameraUsageDescription + NSPhotoLibraryUsageDescription (persists across xcodegen)
- **FlowLayout** — custom SwiftUI Layout for goal pill wrapping

### Files Created
- `Vital/Views/OnboardingView.swift`

### Files Modified
- `Vital/Services/AuthService.swift` — signUp method
- `Vital/Views/LoginView.swift` — signup toggle
- `Vital/Views/ContentView.swift` — profile check + onboarding gate
- `Vital/Views/Activity/ActivityView.swift` — hid active plan card
- `project.yml` — camera + photo library permissions
- `src/app/api/profile/route.ts` (web dashboard) — POST handler
- `src/app/api/targets/route.ts` (web dashboard) — POST handler

### Backend Deployments
- Profile/targets POST routes: force-deployed via `vercel --prod`

### Status
- Onboarding flow: **Complete, pending device test**
- Meal photo scan: **Complete and tested**
- Sync fixes: **Complete and tested**
- Emerald palette: **All views migrated**

### What's Next
1. **Test onboarding** with a new account
2. **Polish scan UX** — loading animations, haptics
3. **App icon** — still needed
4. **iOS 26 SDK upgrade**
5. **App Store screenshots + description**
6. **Submit to App Store**

## 2026-03-29 — Session 9

### Figma Design System & Screens Export
- Created Figma file: `PbVZQjqKOHjBQ9K3seBFjt` — "Vital iOS — Design System & Screens"
- Figma MCP tools confirmed working (authenticated as lou.cesario92@gmail.com, "dev" plan with Full seat)
- **Design System page** — Emerald Health color palette swatches (surfaces, status, interactive, text), typography scale (SF Pro mapped to Inter), card component specs (default + elevated)
- **Today Tab** — greeting header, recovery ring (78 score, arc fill), AI verdict, 2x2 metric grid (Sleep/RHR/Steps/HRV), active calories bar, 3 quick action buttons, Ask Vital gradient button, tab bar
- **Activity Tab** — nutrition summary card (calories + protein bars), active plan card (PPL + HIIT, day buttons), 4 recent workout rows, quick log button, tab bar
- **Profile Tab** — avatar with gradient, name/stats, Ask Vital button, health records section (Labs/Supplements/Health Profile with badge), trends (Weight/HRV/RHR with deltas), settings list, tab bar
- **Chat View** — back nav, welcome card, suggestion chips, user message bubble, AI response bubble, input bar with send button
- **Nutrition View** — date nav arrows, macro summary card (4 bars: cal/protein/carbs/fat), weekly calorie chart (7 mini bars), grouped meal list (Breakfast/Lunch/Snack)
- **Meal Form** — sheet with handle, meal type chips, 5 form fields (name/cal/protein/carbs/fat), submit button
- **Hit Figma Starter plan rate limit** after 6 screens — remaining ~11 screens need rate limit reset or plan upgrade

### Screens Still Needed (when limit resets)
- Workouts View, Workout Detail, Quick Log, Workout Session
- Labs View, Supplements View, Supplement Form
- Login View, Metric Detail View, Water Quick-Add, Recovery Info Sheet

### Files Created
- Figma file: https://www.figma.com/design/PbVZQjqKOHjBQ9K3seBFjt

### Files Modified
- `docs/changelog.md` — this entry
- `docs/build-plan.md` — added Figma export line item

### Decisions
- Used "dev" Figma plan (Full seat) over "Vault 721" (View-only seat)
- Inter font used in Figma as proxy for SF Pro (system font not available in Figma)
- All screens built at 393×852 (iPhone 14 Pro dimensions)
- Emerald Health palette colors matched exactly from BrandColors.swift

### Status
- Figma export: **6/~17 screens complete, rate limited**
- App icon: **Still needed**
- iOS 26 SDK: **Not started**
- App Store screenshots/description: **Not started**
- Device test of emerald palette: **Not done yet**

### What's Next
1. **Wait for Figma rate limit reset** or upgrade plan → finish remaining 11 screens
2. **Test emerald palette on device** — build + run
3. **App icon** — design externally (AI image gen, Figma, or designer)
4. **iOS 26 SDK upgrade**
5. **App Store screenshots + description**
6. **Submit to App Store**

## 2026-03-29 — Session 8

### Demo User Seed Script
- **scripts/seed-demo-user.ts** — standalone script that creates a fully populated demo user (Alex Rivera) for App Store review and demos
- Creates Supabase auth user via admin API (`demo@vital.app` / `VitalDemo2026!`)
- Idempotent: deletes all existing demo data before re-seeding
- `--clean` flag for delete-only mode
- Generates 90 days of internally consistent data across all tables:
  - **daily_metrics** (90 rows) — weight trending 175→169, HRV trending up, RHR trending down, sleep/mood/energy correlations, weekend patterns
  - **lab_results** (55 rows) — 2 draw dates (baseline with flags + 60-day improvement), full CMP/CBC/lipids/hormones/vitamins
  - **workouts** (68 rows) — Push/Pull/Legs/Upper/HIIT/Walking split, Apple Watch source, heart rate data
  - **exercise_log** (242 rows) — 4-6 exercises per strength workout with progressive overload on weights
  - **nutrition_log** (355 rows) — realistic meal prep bowls, shakes, snacks, occasional restaurant meals
  - **supplements** (9 rows) — 8 active + 1 paused (pre-workout stopped due to sleep impact)
  - **action_items** (12 rows) — mix of Done/Ongoing/In Progress/Not Started
  - **saved_workout_plans** (1 row) — PPL + HIIT split with full exercise details matching iOS PlanDay model
  - **profile** — Alex Rivera, 31M, Austin TX, body recomp goal
  - **user_targets** — 1700-2100 cal, 140-170g protein, 9000 steps, 80oz water
- Validates all row counts after seeding
- Installed `tsx` and `dotenv` as devDependencies in web dashboard

### Emerald Health Color Palette
- Updated BrandColors.swift with Emerald Health palette:
  - Background: dark forest `#0E1210` (was near-black `#0A0A0C`)
  - Cards: dark green-gray `#161E1A` (was `#141418`)
  - Accent: emerald `#5BA88C` (was blue `#00B4D8`)
  - Secondary: dark amber `#C8923A` (was purple `#8B5CF6`)
  - Warning: bright gold `#E0A840` (was amber `#FFB547`)
  - Optimal: sage green `#5AB88C` (was bright green `#00D68F`)
  - Text primary: cream-green `#E8F0EC` (was pure white)
  - Gradients: forest→sage (was blue→purple)
- Moved `Color(hex:)` extension from ContentView.swift into BrandColors.swift (was causing build errors when referenced from other files)

### Bug Fix
- **Activity tab decode error** — plan_data JSONB shape didn't match iOS PlanDay model (used `day`/`focus` instead of `dayNumber`/`name`/`isRest`/`exercises`). Fixed seed script to output correct shape with `dayNumber`, `restSeconds`, `order` fields.

### Files Created
- `scripts/seed-demo-user.ts` (in web dashboard repo)

### Files Modified
- `Vital/BrandColors.swift` — Emerald Health palette + Color(hex:) extension
- `Vital/Views/ContentView.swift` — removed duplicate Color(hex:) extension
- `docs/build-plan.md` — checked off demo account, brand color pass
- `docs/changelog.md` — this entry

### Dependencies Added (web dashboard)
- `tsx` (devDependency) — run TypeScript scripts
- `dotenv` (devDependency) — load .env.local in scripts

### Decisions
- Demo user is "Alex Rivera" (not Lou) — separate identity for App Store reviewer
- Emerald Health palette chosen over original blue/purple — user selected from screenshot swatches
- Gold/amber added as secondary color per user request
- Figma MCP is configured but needs Claude Code restart to load tools
### Status
- Demo account: **Complete and tested on device**
- Emerald color palette: **Applied, needs device test**
- App icon: **Still needed**
- Figma MCP: **Configured, needs session restart to activate**

### What's Next
1. **Restart Claude Code** to load Figma MCP tools
2. **Export all screens to Figma** — editable components + design system
3. **App icon** — design externally (AI image gen, designer, or Figma)
4. **Test emerald palette on device** — verify all screens look good
5. **App Store screenshots + description**
6. **Upgrade to iOS 26 SDK**
7. **Submit to App Store**

## 2026-03-29 — Session 7 (continued)

### Bug Fixes
- **AI Chat SSE parsing** — was showing raw JSON chunks (`{"type":"text","text":"..."}`) instead of extracting text. Fixed parser to only extract `text` field from `type: "text"` events, skip control events (conversation_id, remaining)
- **AI Chat markdown rendering** — `**bold**` showing as raw text. SwiftUI `Text()` doesn't render markdown from variables. Fixed with `AttributedString(markdown:)` using `inlineOnlyPreservingWhitespace` option
- **Pull-to-refresh network error** — `syncAndRefresh()` was creating a throwaway `SyncService` instance that failed. Changed to just reload data from API (HealthKit sync happens automatically via background delivery)
- **Water quick-add buttons not working** — haptics fired but API call silently failed. Root cause: `POST /api/metrics` uses `.insert()` which fails on duplicate date (HealthKit sync already created the row). Added `PATCH /api/metrics` route with upsert. Vercel auto-deploy didn't trigger — had to force deploy
- **Metric card height mismatch** — Resting HR card shorter than others (no subtitle). Fixed by always rendering subtitle line with invisible placeholder when nil
- **Lab range bar dot misalignment** — switched from `offset` to `position` centering so dot, bar, and optimal zone share same vertical center
- **Water streak bar overflow** — Sunday bar overlapping. Replaced `GeometryReader` with `ZStack(alignment: .bottom)` + `.clipped()`

### Animations Added
- **Lab range bars** — bars shoot out from left (0.5s easeOut), then dot slides in and lands with spring bounce (0.3s delay)
- **Water streak bars** — all 7 bars grow upward from bottom (0.6s easeOut, 0.2s delay)
- **Today tab pull-to-refresh animations:**
  - Recovery ring re-animates from 0 → score (forced re-init via UUID key)
  - 4 metric cards pop in with staggered scale bounce (0.92 → 1.0, 70ms apart)
  - Calories bar fills left to right (0.7s easeOut)
  - All reset and replay on every refresh

### Water Widget Enhancements
- "Daily Goal" label always visible
- Goal celebration: ring turns green, checkmark icon, "Goal reached!" text
- 7-day streak bars: vertical bars per day, green = goal met, blue = partial, gray = none

### Workout Plans — Noted for Future
- No way to generate workout plans from iOS (AI plan generator is web-only)
- Added to build plan: Safari link, read-only plan view, native plan generator (future)

### Files Modified
- `Vital/Views/More/ChatView.swift` — SSE parser fix (extract text type only), markdown rendering via AttributedString
- `Vital/Views/Today/TodayView.swift` — pull-to-refresh fix, staggered metric animations, calories bar animation, recovery ring re-animation
- `Vital/Views/Today/WaterQuickAddView.swift` — goal celebration, streak bar animation, bar overflow fix
- `Vital/Views/More/LabsView.swift` — range bar dot alignment fix, bar + dot entrance animations
- `docs/build-plan.md` — added Workout Plans future section

### Status
- All V2 features: **Complete and tested on device**
- Known working: Today tab, Activity tab, Profile tab, AI chat, labs, supplements CRUD, water tracking
- Pull-to-refresh: **Fixed**
- AI chat: **Fixed** (streaming + markdown)

### What's Next
1. **App icon** — Vital gradient (blue → purple)
2. **App Store screenshots** — capture all 3 tabs + key detail views
3. **App Store description** — write copy
4. **Demo account** — create for Apple reviewer
5. **Submit to App Store**

## 2026-03-29 — Session 7

### WorkoutDetailView Upgrade
- Full rewrite: header with type badge, stats row (duration/cals/avg HR/max HR), muscle group pills
- Exercise log fetched from `GET /api/exercises?date=YYYY-MM-DD`
- Each exercise: name, sets × reps @ weight, muscle group badge
- Empty state with "Add what you did" CTA
- **AddExerciseView**: search exercise library (`GET /api/library`), auto-fill muscle group, sets/reps/weight, saves via `POST /api/exercises`, resets for adding more
- `ExerciseLogEntry` + `ExerciseLogBody` models added to AppModels

### Water Quick-Add
- **WaterQuickAddView.swift**: progress ring (current oz / target oz), "Daily Goal" label
- Quick buttons: 8 oz, 16 oz, 24 oz + custom amount field
- Goal celebration: ring turns green, checkmark icon, "Goal reached!" text when target hit
- **7-day streak bars**: vertical bars for each day of the week, green = goal met, blue = partial, gray = none, today highlighted
- Uses `PATCH /api/metrics` (upsert by date) instead of POST (which failed on duplicate date)
- Wired into TodayView water quick action button

### Water Bug Fix
- **Bug**: Water buttons had haptic feedback but nothing happened
- **Root cause**: `POST /api/metrics` uses `.insert()` which fails when a row already exists for today (HealthKit sync creates it)
- **Fix**: Added `PATCH /api/metrics` route to backend — upserts by user_id + date. Supports waterOz, weightLbs, mood, energy, focus, notes
- Had to force-deploy via `vercel --prod` (auto-deploy didn't trigger)

### Labs Upload from iOS
- Upload card at top of LabsView with purple gradient
- **DocumentPicker.swift**: UIViewControllerRepresentable wrapping UIDocumentPickerViewController for PDF
- Multipart form upload to `POST /api/labs/parse` (Claude AI parses the PDF)
- Progress spinner: "Parsing lab results with AI..."
- Saves each parsed result via `POST /api/labs`, shows "Parsed X biomarkers, saved Y"
- Auto-refreshes lab list on success

### Brand Colors System
- **BrandColors.swift**: centralized `Brand.*` enum — bg, card, elevated, textPrimary/Secondary/Muted, optimal/warning/critical, accent/secondary, gradients
- All views updated to use `Brand.*` instead of hardcoded hex values
- Tested earthy palette (Forest/Cream/Terracotta/Sage/Sand) — looked clean but user preferred original palette
- Reverted to original colors in BrandColors.swift — all views still reference `Brand.*` so re-skinning is a one-file change

### Metric Card Alignment Fix
- All 4 metric cards on TodayView now have equal height
- Cards without a subtitle (Resting HR) render an invisible placeholder line

### APIService Updates
- Added `patchRaw` method for raw JSON PATCH requests
- `authService` changed from private to public (needed for lab upload auth header)

### Files Created
- `Vital/Views/Today/WaterQuickAddView.swift`
- `Vital/Views/Components/DocumentPicker.swift`
- `Vital/BrandColors.swift`
- `docs/ios-v2-ux-redesign.md`

### Files Modified (iOS)
- `Vital/Views/Workouts/WorkoutDetailView.swift` — full rewrite with exercise log + AddExerciseView
- `Vital/Views/More/LabsView.swift` — upload card, DocumentPicker, multipart upload logic
- `Vital/Views/Today/TodayView.swift` — water sheet, Brand colors, metric card height fix
- `Vital/Models/AppModels.swift` — ExerciseLogEntry + ExerciseLogBody
- `Vital/Services/APIService.swift` — patchRaw, public authService
- All views updated to Brand.* color references (ContentView, ActivityView, ProfileView, MoreView, SupplementsView, SupplementFormView, MetricDetailView)

### Files Modified (Web Dashboard)
- `src/app/api/metrics/route.ts` — added PATCH handler (upsert water/weight/mood by date)

### Backend Deployments
- PATCH /api/metrics deployed to Vercel (force deploy required)

### Status
- V2 UX Redesign: **All code items complete**
- Color system: **Centralized in BrandColors.swift**, original palette active, ready for re-skin
- All features: **Pending device testing**

### What's Next
1. **Test on device** — water widget, workout exercise log, labs upload, all tabs
2. **App icon** — Vital gradient (blue → purple)
3. **App Store prep** — screenshots, description, demo account
4. **Oura** — check if additional users approved
5. **Submit to App Store**

## 2026-03-29 — Session 6

### WorkoutDetailView Upgrade
- Full rewrite with exercise log integration
- Header: workout name, date, type badge (color-coded by type)
- Stats row: duration, active calories, avg HR, max HR
- Muscle group pills (horizontal scroll, purple badges)
- Exercise log fetched from `GET /api/exercises?date=YYYY-MM-DD`
- Each exercise row: name, sets × reps @ weight, muscle group badge
- Empty state: "No exercises logged" with "Add what you did" CTA
- **AddExerciseView** — search exercise library (`GET /api/library`), auto-fill muscle group on selection, sets/reps/weight fields, saves via `POST /api/exercises`, resets form for adding more

### Water Quick-Add
- **WaterQuickAddView.swift** — sheet with progress ring (current oz / target oz)
- Quick buttons: 8 oz, 16 oz, 24 oz (PressScaleButtonStyle)
- Custom amount text field + "Add" button
- Updates daily_metrics water_oz via `POST /api/metrics`
- Animated progress ring on each add
- Loads current water + target on appear from `/api/metrics` + `/api/targets`
- Wired into TodayView water quick action button (was placeholder)

### Labs Upload from iOS
- **Upload card** at top of LabsView — purple gradient, "Upload Lab Results" with "PDF auto-parsed by AI" subtitle
- **DocumentPicker.swift** — UIViewControllerRepresentable wrapping UIDocumentPickerViewController for PDF selection
- Multipart form upload to `POST /api/labs/parse` (Claude parses the PDF)
- Progress state: "Parsing lab results with AI..." with spinner
- On success: saves each parsed result individually via `POST /api/labs`
- Success message: "Parsed X biomarkers, saved Y"
- Error handling with friendly messages
- Auto-refreshes lab list after upload
- 60-second timeout for AI parsing

### Models Added
- `ExerciseLogEntry` — id, exercise, workoutDate, muscleGroup, sets, reps, weightLbs, restSec, notes
- `ExerciseLogBody` — Codable struct for POST /api/exercises

### Files Created
- `Vital/Views/Today/WaterQuickAddView.swift`
- `Vital/Views/Components/DocumentPicker.swift`

### Files Modified
- `Vital/Views/Workouts/WorkoutDetailView.swift` — full rewrite with exercise log + AddExerciseView
- `Vital/Views/More/LabsView.swift` — upload card, DocumentPicker sheet, multipart upload logic
- `Vital/Views/Today/TodayView.swift` — showWater state + WaterQuickAddView sheet wired to water button
- `Vital/Models/AppModels.swift` — ExerciseLogEntry + ExerciseLogBody models
- `Vital/Services/APIService.swift` — added `patchRaw` method, `authService` made public (needed for lab upload auth)

### Status
- V2 UX Redesign: **All code items complete** (except brand bible color pass)
- WorkoutDetailView: **Complete** (pending device test)
- Water quick-add: **Complete** (pending device test)
- Labs upload: **Complete** (pending device test)

### What's Next
1. **Test on device** — all 3 new features
2. **Brand bible color pass** — apply brand colors when provided
3. **App icon** — Vital gradient (blue → purple)
4. **App Store prep** — screenshots, description, demo account
5. **Submit to App Store**

*Sessions 3-5 archived in [changelog-archive.md](changelog-archive.md)*

