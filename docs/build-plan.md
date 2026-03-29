# Build Plan — Vital iOS App

## Phase 1 — Core Sync (Complete)
- [x] Create Xcode project with HealthKit + Background Modes capabilities
- [x] Add Supabase Swift SDK dependency (Swift Package Manager)
- [x] Build LoginView (email + password, matches web app dark theme)
- [x] Build AuthService (sign in, sign out, session persistence)
- [x] Build HealthKitService (permission request, data queries)
- [x] Build PermissionsView (request HealthKit access, explain each metric)
- [x] Build SyncService (format data, POST to ingest API)
- [x] Build SyncStatusView (last sync time, manual sync button, sync log)
- [x] Wire up: login -> permissions -> auto-sync
- [x] Test on physical device with real Apple Watch data
- [x] Update backend ingest route to accept Supabase access tokens

## Phase 2 — Background Sync (Complete)
- [x] Register HealthKit background delivery for all metric types
- [x] Register BGTaskScheduler for periodic sync fallback
- [x] Handle app lifecycle (scenePhase changes trigger sync)
- [x] Save/restore lastSyncDate in UserDefaults
- [ ] Test background sync (kill app, generate health data, verify sync)

## Phase 3 — Sync Polish (Complete)
- [x] Error handling (network failures, expired tokens, HealthKit denied)
- [x] Retry logic with exponential backoff
- [x] Privacy policy page — hosted at /privacy on dashboard
- [x] Launch screen (dark background)

## Phase 4 — V1 Full App (see docs/ios-v1-spec.md for details)

### Foundation
- [x] Build APIService.swift (generic REST client with auth)
- [x] Build AppModels.swift (Codable structs for all API responses)
- [x] Update Config.swift with apiBaseURL constant
- [x] Update ContentView.swift — TabView after auth+permissions

### Dashboard Tab
- [x] DashboardView — fetch metrics + targets, card layout
- [x] RecoveryRing — custom Shape with score + color
- [x] SparklineChart — 7-day HRV/RHR mini trends (Swift Charts)
- [x] MacroBar — reusable progress bar component
- [x] Activity progress bars (steps, exercise, calories)
- [x] Streak counter
- [x] Last synced indicator
- [x] Pull-to-refresh triggers sync + data refresh

### Nutrition Tab
- [x] NutritionView — date nav, macro bars, grouped meal list
- [x] MealFormView — add/edit sheet
- [x] Swipe-to-delete on meals
- [x] Weekly calorie chart

### Workouts Tab
- [x] WorkoutsView — recent list + saved plans cards
- [x] WorkoutDetailView — stats sheet
- [x] QuickLogView — quick log sheet
- [x] WorkoutSessionView — set tracking + rest timer

### More Tab
- [x] MoreView — navigation hub
- [x] SupplementsView — active stack list
- [x] ChatView — AI health chat with SSE streaming
- [x] SettingsView — expand with profile, targets, sync status, sign out

### Polish & Ship
- [ ] App icon (Vital gradient — blue to purple)
- [ ] Tab bar icons + active states
- [ ] Loading skeletons / pull-to-refresh animations
- [ ] Haptic feedback on key actions
- [ ] Handle offline state gracefully
- [ ] App Store screenshots
- [ ] App Store description
- [ ] Demo account for Apple reviewer
- [ ] Upgrade to iOS 26 SDK
- [ ] Submit to App Store
