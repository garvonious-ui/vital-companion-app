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

### Phase 4 Foundation
- Built `APIService.swift` — generic REST client (GET/POST/PATCH/DELETE + SSE streaming), snake_case JSON, flexible date parsing, Bearer auth via AuthService
- Built `AppModels.swift` — all Codable structs: DailyMetric, UserTargets, Workout, WorkoutPlan, NutritionEntry, Supplement, UserProfile, ChatMessage, LibraryExercise, ExerciseSet, etc.
- Updated `Config.swift` — added `apiBaseURL` constant (localhost debug, Vercel release)
- Updated `ContentView.swift` — replaced SyncStatusView with MainTabView (4 tabs: Dashboard, Workouts, Nutrition, More) with dark-themed tab bar styling
- Updated `VitalApp.swift` — wired APIService as @StateObject + .environmentObject

### Dashboard Tab
- Built `DashboardView.swift` — recovery card, activity card, trends card, sync indicator, pull-to-refresh, error state, parallel API fetching
- Built `RecoveryRing.swift` — custom animated ring Shape with score, color coding (green/amber/red), status label
- Built `SparklineChart.swift` — 7-day mini trend using Swift Charts (LineMark + AreaMark gradient)
- Built `MacroBar.swift` — reusable progress bar with label, current/target, color, smart number formatting
- Recovery algorithm: HRV 50% + RHR 30% + Sleep 20% (matches web app)
- Streak counter: consecutive days with workout or 9k+ steps

### Files Created
- `Vital/Services/APIService.swift`
- `Vital/Models/AppModels.swift`
- `Vital/Views/Dashboard/DashboardView.swift`
- `Vital/Views/Components/RecoveryRing.swift`
- `Vital/Views/Components/SparklineChart.swift`
- `Vital/Views/Components/MacroBar.swift`

### Files Modified
- `Vital/Config.swift` — added apiBaseURL
- `Vital/Views/ContentView.swift` — TabView + MainTabView
- `Vital/VitalApp.swift` — APIService wiring

### Nutrition Tab
- Built `NutritionView.swift` — date navigation (left/right arrows, tap to snap to today), macro summary card (calories, protein, carbs, fat vs targets using MacroBar), weekly calorie bar chart (Swift Charts BarMark with target line), meals grouped by type (breakfast > lunch > dinner > snack > shake) with subtotals, pull-to-refresh, empty state with "Log a Meal" CTA
- Built `MealFormView.swift` — add/edit sheet with meal type picker (horizontal chip row), name field, calorie + macro fields, dark-themed text field style, POST for new meals, PATCH for edits
- Swipe-to-delete on meal rows (DELETE /nutrition?id=xxx)
- Weekly calorie chart with highlighted selected day + dashed target line
- `DarkFieldStyle` — reusable dark text field style component

### Files Created
- `Vital/Views/Nutrition/NutritionView.swift`
- `Vital/Views/Nutrition/MealFormView.swift`

### Files Modified
- `Vital/Views/ContentView.swift` — removed NutritionView placeholder

### Workouts Tab
- Built `WorkoutsView.swift` — saved plans section (plan cards with day selector buttons), recent workouts list with type badges + color-coded icons (strength/running/cycling/swimming/hiit/yoga/walking), workout type icon mapping, pull-to-refresh, empty state
- Built `WorkoutDetailView.swift` — stats sheet with type badge, duration/calories/exercises/sets stats row, exercise list with per-set weight × reps display, notes card
- Built `QuickLogView.swift` — 4-column type picker grid (8 workout types with icons), name/duration/calories/notes fields, POST to /api/workouts
- Built `WorkoutSessionView.swift` — full workout session from plan day: per-exercise set tracking (weight + reps input), checkmark to complete sets, rest timer overlay with countdown ring + preset buttons (1:00/1:30/2:00/3:00), session elapsed timer, exercise navigation (previous/next), progress bar (completed/total sets), haptic feedback, save & finish (POST exercises with sets), discard option
- Added `postRaw` method to APIService for dynamic JSON payloads

### Files Created
- `Vital/Views/Workouts/WorkoutsView.swift`
- `Vital/Views/Workouts/WorkoutDetailView.swift`
- `Vital/Views/Workouts/QuickLogView.swift`
- `Vital/Views/Workouts/WorkoutSessionView.swift`

### Files Modified
- `Vital/Views/ContentView.swift` — removed WorkoutsView placeholder
- `Vital/Services/APIService.swift` — added postRaw method

### Status
Phase 4 Foundation: **Complete**
Phase 4 Dashboard Tab: **Complete**
Phase 4 Nutrition Tab: **Complete**
Phase 4 Workouts Tab: **Complete**
### More Tab
- Built `MoreView.swift` — profile card (avatar with gradient initials, name, email, goal), nav cards to Supplements + AI Chat, sync status indicator, settings/web dashboard/privacy links
- Built `SupplementsView.swift` — active stack grouped by timing (morning, with meals, pre-workout, post-workout, evening, as needed), type emoji badges, dosage display, timing icons, pull-to-refresh, empty state
- Built `ChatView.swift` — AI health chat with SSE streaming: welcome card with suggestion chips, message bubbles (user blue-tinted, assistant dark), streaming indicator dots, SSE line parser (data: JSON tokens + [DONE] sentinel), auto-scroll, stop button, multi-line input
- Expanded `SettingsView.swift` — profile section (name, email, goal, weight), daily targets section with color dots, sync section (last sync time, frequency, recent sync log from UserDefaults), about section (version, web dashboard, privacy), sign out with confirmation dialog

### Files Created
- `Vital/Views/More/MoreView.swift`
- `Vital/Views/More/SupplementsView.swift`
- `Vital/Views/More/ChatView.swift`

### Files Modified
- `Vital/Views/SettingsView.swift` — full rewrite with profile, targets, sync log
- `Vital/Views/ContentView.swift` — removed MoreView placeholder

### Status
Phase 4 Foundation: **Complete**
Phase 4 Dashboard Tab: **Complete**
Phase 4 Nutrition Tab: **Complete**
Phase 4 Workouts Tab: **Complete**
Phase 4 More Tab: **Complete**
Next: Polish & Ship
