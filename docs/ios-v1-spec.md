# Vital iOS V1 — Full Native App Spec

## Context
The current setup requires two apps (companion sync app + Safari web dashboard) which is a broken UX. The goal is to merge them into one native iOS app that handles both HealthKit sync AND data display. The companion app already has auth, HealthKit, sync, and retry logic — we're extending it, not starting from scratch.

V1 ships the features you actually use on your phone. Desktop-heavy features (lab PDF upload, AI plan generator questionnaire) stay on the web.

## What Already Exists (companion app)
- **Auth:** Supabase email/password, token refresh, session persistence
- **HealthKit:** 8 data types, background delivery, smart deduplication
- **Sync:** Retry with exponential backoff, sync log, lastSyncDate persistence
- **Views:** Login, Permissions, SyncStatus, Settings
- **Config:** Supabase URLs, ingest endpoint, dark theme colors
- **Dependencies:** Supabase Swift SDK, native Apple frameworks only
- **Project:** iOS 17+, bundle ID `com.vital.health`, xcodegen

## Backend (no changes needed)
All API routes already exist on the web dashboard (https://vital-health-dashboard.vercel.app) and return JSON:
- `GET /api/metrics` — daily health metrics
- `GET /api/workouts` — workout history
- `GET /api/nutrition` — meal log
- `POST /api/nutrition` — log meal
- `PATCH /api/nutrition` — edit meal
- `DELETE /api/nutrition?id=xxx` — delete meal
- `GET /api/targets` — user daily targets
- `GET /api/profile` — user profile
- `GET /api/supplements` — supplement stack
- `GET /api/plans` — saved workout plans
- `POST /api/ingest/apple-health` — HealthKit sync (already used by companion app)
- `POST /api/ai/chat` — AI health chat (SSE streaming)

All routes require Bearer token auth (Supabase access token). Response format: `{ success: true, data: [...] }` or `{ success: false, error: "message" }`.

---

## V1 Feature Scope

### Tab 1: Dashboard (Home)
- Recovery ring (score 0-100, color-coded: green 67+, amber 34-66, red 0-33)
- Recovery algorithm: HRV 50% + RHR 30% + Sleep 20% (see web app docs/recovery-algorithm.md)
- Activity progress bars (Steps, Exercise, Calories vs user targets)
- Streak counter (consecutive days with workout or 9k+ steps)
- HRV + RHR sparklines (7-day mini trend)
- Last synced indicator
- Pull-to-refresh triggers HealthKit sync + data refresh

**Data:** `GET /api/metrics` + `GET /api/targets`

### Tab 2: Workouts
- Recent workouts list (type badge, duration, calories, date)
- Saved plans section (plan name, days/week, "Start Workout" button)
- Quick Log form (type, duration, calories — sheet)
- Full workout session (exercise list from plan, set tracking with weight/reps per set, rest timer with presets)

**Data:** `GET /api/workouts`, `GET /api/plans`, `GET /api/library`, `POST /api/workouts`, `POST /api/exercises`

### Tab 3: Nutrition
- Date navigation (left/right arrows, today snap)
- Macro progress bars (calories, protein, carbs, fat vs targets)
- Meals grouped by type (Breakfast > Lunch > Dinner > Snack > Shake) with subtotals
- Log Meal sheet (name, type, calories, protein, carbs, fat)
- Tap meal to edit, swipe to delete

**Data:** `GET /api/nutrition`, `POST/PATCH/DELETE /api/nutrition`, `GET /api/targets`

### Tab 4: More
- **Supplements** — active stack list (name, type badge, dosage, timing)
- **AI Chat** — health assistant with streaming responses (has access to real health data)
- **Settings** — profile display, daily targets, sync status/log, sign out
- Links to web app for Labs, Progress Photos

**Data:** `GET /api/supplements`, `POST /api/ai/chat` (SSE), `GET /api/profile`

---

## Design System

### Colors (match web app exactly)
- Background: `#0A0A0C`
- Cards: `#141418`
- Elevated: `#1C1C22`
- Text primary: `#FFFFFF`
- Text secondary: `#A0A0B0`
- Text muted: `#606070`
- Green (optimal): `#00D68F`
- Amber (warning): `#FFB547`
- Red (critical): `#FF4757`
- Blue (accent): `#00B4D8`
- Purple (secondary): `#8B5CF6`

### Typography
- Display/headings: system bold (SF Pro matches the premium feel)
- Body: system regular
- Numbers/metrics: `.monospacedDigit()` modifier

### Card Style
- Corner radius: 12-16pt
- Border: 1px `white.opacity(0.06)`
- Background: `#141418`

---

## Architecture

### Navigation
```
TabView (4 tabs)
├── DashboardTab
├── WorkoutsTab → WorkoutDetail, WorkoutSession, QuickLog
├── NutritionTab → MealForm (sheet)
└── MoreTab → SupplementsList, ChatView, SettingsView
```

### New Service Layer
```
APIService.swift — generic GET/POST/PATCH/DELETE with auth headers
  - Uses existing AuthService for Bearer token
  - JSON decoding to Swift Codable models
  - Error handling consistent with SyncService patterns
```

### New Models (Codable structs)
```
DailyMetric — maps to /api/metrics response
Workout — maps to /api/workouts response
NutritionEntry — maps to /api/nutrition response
SavedWorkoutPlan — maps to /api/plans response
Supplement — maps to /api/supplements response
UserProfile — maps to /api/profile response
UserTargets — maps to /api/targets response
ChatMessage — for AI chat
```

### Charts
- Use **Swift Charts** (iOS 16+, native Apple framework)
- Recovery ring: custom `Shape` with `trim()` animation
- Progress bars: custom `GeometryReader` bars or styled `ProgressView`
- Sparklines: `Chart { LineMark(...) }` with minimal styling

---

## File Structure (new/modified files)

```
Vital/
├── Services/
│   ├── AuthService.swift          (existing)
│   ├── HealthKitService.swift     (existing)
│   ├── SyncService.swift          (existing)
│   └── APIService.swift           (NEW — generic REST client)
├── Models/
│   ├── HealthData.swift           (existing — sync models)
│   └── AppModels.swift            (NEW — all response models)
├── Views/
│   ├── ContentView.swift          (MODIFY — add TabView after auth)
│   ├── LoginView.swift            (existing)
│   ├── PermissionsView.swift      (existing)
│   ├── Dashboard/
│   │   ├── DashboardView.swift    (NEW)
│   │   └── RecoveryRing.swift     (NEW — custom Shape)
│   ├── Workouts/
│   │   ├── WorkoutsView.swift     (NEW — list + plans)
│   │   ├── WorkoutDetailView.swift (NEW)
│   │   ├── WorkoutSessionView.swift (NEW — set tracking + timer)
│   │   └── QuickLogView.swift     (NEW)
│   ├── Nutrition/
│   │   ├── NutritionView.swift    (NEW — date nav + macros + meals)
│   │   └── MealFormView.swift     (NEW — add/edit sheet)
│   ├── More/
│   │   ├── MoreView.swift         (NEW — hub)
│   │   ├── SupplementsView.swift  (NEW)
│   │   ├── ChatView.swift         (NEW — AI health chat with SSE)
│   │   └── SettingsView.swift     (MODIFY — expand)
│   └── Components/
│       ├── MacroBar.swift         (NEW — reusable progress bar)
│       ├── SparklineChart.swift   (NEW — mini trend chart)
│       └── MealTypeIcon.swift     (NEW)
├── VitalApp.swift                 (MODIFY — keep bg sync, update root view)
└── Config.swift                   (MODIFY — add API base URL constant)
```

**~20 new files, ~4 modified files**

---

## Build Order

### Phase 1: Foundation (Day 1-2)
1. `APIService.swift` — generic REST client with auth
2. `AppModels.swift` — all Codable response models
3. `Config.swift` — add `apiBaseURL` constant
4. `ContentView.swift` — swap SyncStatusView for TabView after auth+permissions

### Phase 2: Dashboard Tab (Day 2-3)
5. `DashboardView.swift` — fetch metrics + targets, layout cards
6. `RecoveryRing.swift` — custom ring shape with score
7. `SparklineChart.swift` — 7-day mini trend for HRV/RHR
8. `MacroBar.swift` — reusable progress bar component
9. Pull-to-refresh triggers SyncService

### Phase 3: Nutrition Tab (Day 3-4)
10. `NutritionView.swift` — date nav, macro bars, grouped meal list
11. `MealFormView.swift` — add/edit sheet with all fields
12. Swipe-to-delete on meal rows

### Phase 4: Workouts Tab (Day 4-6)
13. `WorkoutsView.swift` — recent list + saved plans cards
14. `WorkoutDetailView.swift` — stats modal
15. `QuickLogView.swift` — quick log sheet
16. `WorkoutSessionView.swift` — full session with set tracking + rest timer

### Phase 5: More Tab (Day 6-7)
17. `MoreView.swift` — navigation hub
18. `SupplementsView.swift` — active stack list
19. `ChatView.swift` — AI chat with SSE streaming
20. `SettingsView.swift` — expand with profile display, sync status, sign out

### Phase 6: Polish (Day 7-8)
21. App icon (Vital gradient — blue #00B4D8 to purple #8B5CF6)
22. Tab bar icons + active states
23. Loading skeletons / pull-to-refresh animations
24. Haptic feedback on key actions
25. Handle offline state gracefully

---

## Not in V1 (stays on web)
- Labs page (PDF upload needs file picker UX)
- Lab range bar visualizations
- Progress photos (camera + storage)
- AI workout plan questionnaire (6-step chat flow)
- Oura/Whoop/Garmin OAuth device connections
- Workout frequency heatmap, progressive overload chart
- Onboarding wizard (use web for initial setup)
- Edit profile / edit targets (use web Settings)

## Web App Reference
- Repo: github.com/garvonious-ui/vital-health-dashboard
- Live: https://vital-health-dashboard.vercel.app
- CLAUDE.md: /Users/loucesario/Health app/vital-health-dashboard/CLAUDE.md
- Recovery algorithm: /Users/loucesario/Health app/vital-health-dashboard/docs/recovery-algorithm.md
- Design system: /Users/loucesario/Health app/vital-health-dashboard/docs/design-system.md
- Supabase schema: /Users/loucesario/Health app/vital-health-dashboard/docs/supabase-schema.md
