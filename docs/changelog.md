# Changelog — Vital Companion App

## 2026-03-27 — Session 1

### Initial Scaffold
- Created project directory structure
- Created all Swift source files (VitalApp, Views, Services, Models)
- Created CLAUDE.md, docs, slash commands
- Updated web backend ingest route to accept Supabase access tokens

### Files Created
- `Vital/VitalApp.swift` — App entry point with background task registration
- `Vital/Config.swift` — Environment config (Supabase URL, keys, API URL)
- `Vital/Views/LoginView.swift` — Email + password sign in
- `Vital/Views/PermissionsView.swift` — HealthKit permission request
- `Vital/Views/SyncStatusView.swift` — Main screen with sync status
- `Vital/Views/SettingsView.swift` — Sign out, debug info
- `Vital/Views/ContentView.swift` — Root view (auth gate)
- `Vital/Services/AuthService.swift` — Supabase auth
- `Vital/Services/HealthKitService.swift` — HealthKit queries + background delivery
- `Vital/Services/SyncService.swift` — Format + POST to ingest API
- `Vital/Models/HealthData.swift` — Data models

### What's Next
- Create Xcode project, add files, add HealthKit + Background Modes capabilities
- Add Supabase Swift SDK via Swift Package Manager
- Test on physical device

### Status
Phase 1: **Scaffolded** — needs Xcode project setup + device testing

## 2026-03-29 — Session 2

### Built: Phase 4 V1 Full App (all 4 tabs)

**Foundation**
- `APIService.swift` — generic REST client (GET/POST/PATCH/DELETE/postRaw + SSE streaming), snake_case JSON, flexible date parsing, Bearer auth
- `AppModels.swift` — 15 Codable structs: DailyMetric, UserTargets, Workout, WorkoutPlan, NutritionEntry, Supplement, UserProfile, ChatMessage, etc.
- `Config.swift` — added `apiBaseURL` (localhost debug, Vercel release)
- `ContentView.swift` — replaced SyncStatusView with MainTabView (4 tabs) + dark tab bar styling
- `VitalApp.swift` — wired APIService as @StateObject + .environmentObject

**Dashboard Tab**
- `DashboardView.swift` — recovery card, activity card, 7-day trends card, sync indicator, pull-to-refresh, error state, parallel API fetching
- `RecoveryRing.swift` — animated ring with score + color coding (green 67+, amber 34-66, red 0-33)
- `SparklineChart.swift` — Swift Charts LineMark + AreaMark gradient for HRV/RHR
- `MacroBar.swift` — reusable progress bar with smart number formatting
- Recovery algorithm: HRV 50% + RHR 30% + Sleep 20%
- Streak counter: consecutive days with workout or 9k+ steps

**Nutrition Tab**
- `NutritionView.swift` — date nav, macro summary (cal/protein/carbs/fat vs targets), weekly calorie bar chart, meals grouped by type with subtotals, swipe-to-delete, empty state
- `MealFormView.swift` — add/edit sheet, meal type chip picker, POST/PATCH
- `DarkFieldStyle` — reusable dark text field style

**Workouts Tab**
- `WorkoutsView.swift` — saved plans with day selector buttons, recent workouts with color-coded type badges (8 types), empty state
- `WorkoutDetailView.swift` — stats sheet (duration/calories/exercises/sets), per-set weight × reps display, notes
- `QuickLogView.swift` — 4-column type grid, name/duration/calories/notes fields, POST
- `WorkoutSessionView.swift` — set tracking (weight/reps input per set), rest timer overlay with countdown ring + presets (1:00/1:30/2:00/3:00), session elapsed timer, exercise navigation, progress bar, haptic feedback, save & finish, discard option

**More Tab**
- `MoreView.swift` — profile card (gradient avatar + initials), nav cards to Supplements + AI Chat, sync status, settings/web/privacy links
- `SupplementsView.swift` — active stack grouped by timing, type emoji badges, dosage display
- `ChatView.swift` — AI chat with SSE streaming, welcome card with suggestion chips, streaming dots, auto-scroll, stop button
- `SettingsView.swift` — full rewrite: profile, daily targets with color dots, sync log, sign out with confirmation

### Decisions Made
- API response models are best-guess (couldn't access web app repo — not on this machine). Will need verification against live backend
- Used `postRaw` on APIService for dynamic JSON payloads (workout sessions with nested exercises/sets) since static Codable structs would be too rigid
- Recovery scoring uses linear interpolation: HRV 15-80ms → 0-100, RHR 80-50bpm → 0-100, Sleep 4-8h → 0-100
- Weekly calorie chart fetches each day individually (N+1 requests) — may want to batch this if API supports date ranges

### Known Issues / Risks
- **Not compiled yet** — 15 new files need to be added to Xcode target, expect compile errors
- **API model mismatches likely** — field names, nesting, types may differ from actual backend responses
- **NutritionView weekly chart** makes 7 API calls (one per day) — could be slow
- **WorkoutSessionView** uses `Timer` (not Combine/async) for rest/session timers — works but not SwiftUI-idiomatic
- **Swipe-to-delete on meals** uses `.swipeActions` inside a `VStack`/`ForEach` — may need `List` wrapper to work properly

### Files Created (15)
- `Vital/Services/APIService.swift`
- `Vital/Models/AppModels.swift`
- `Vital/Views/Components/RecoveryRing.swift`
- `Vital/Views/Components/SparklineChart.swift`
- `Vital/Views/Components/MacroBar.swift`
- `Vital/Views/Dashboard/DashboardView.swift`
- `Vital/Views/Nutrition/NutritionView.swift`
- `Vital/Views/Nutrition/MealFormView.swift`
- `Vital/Views/Workouts/WorkoutsView.swift`
- `Vital/Views/Workouts/WorkoutDetailView.swift`
- `Vital/Views/Workouts/QuickLogView.swift`
- `Vital/Views/Workouts/WorkoutSessionView.swift`
- `Vital/Views/More/MoreView.swift`
- `Vital/Views/More/SupplementsView.swift`
- `Vital/Views/More/ChatView.swift`

### Files Modified (6)
- `Vital/Config.swift` — added apiBaseURL
- `Vital/Views/ContentView.swift` — MainTabView, removed all placeholders
- `Vital/Views/SettingsView.swift` — full rewrite
- `Vital/VitalApp.swift` — APIService wiring
- `docs/build-plan.md` — checked off all Phase 4 tab items
- `docs/changelog.md` — this entry

### Status
- Phase 1-3: **Complete** (except background sync device test)
- Phase 4 Foundation: **Complete**
- Phase 4 Dashboard: **Complete**
- Phase 4 Nutrition: **Complete**
- Phase 4 Workouts: **Complete**
- Phase 4 More: **Complete**
- Phase 4 Polish & Ship: **Not started** (0/11)

### What's Next (Session 3)
1. Add all 15 new files to Xcode project target
2. Build (Cmd+B) — fix compile errors
3. Run on physical device — verify each tab loads and API calls succeed
4. Fix API response model mismatches against live backend
5. Start Polish phase if time permits
