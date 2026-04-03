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

### Labs (added Session 4)
- [x] LabResult model in AppModels.swift
- [x] LabsView — read-only, grouped by category, range bars, status badges, trends
- [x] LabRangeBar — SwiftUI port of web RangeBar component
- [x] Nav card in MoreView linking to LabsView

### V2 UX Redesign (Session 4-5) — see docs/ios-v2-ux-redesign.md
- [x] Restructure to 3 tabs: Today, Activity, Profile
- [x] TodayView — greeting, recovery ring + AI verdict, 2x2 metric grid, calories bar, quick actions, Ask Vital
- [x] Recovery ⓘ explainer sheet (score calculation + ranges)
- [x] MetricDetailView — reusable 7/30-day chart, today vs avg, related metrics
- [x] All metric cards + calories bar tappable → detail views
- [x] ActivityView — nutrition summary card, active plan card, recent workouts, quick log
- [x] ProfileView — profile header, Ask Vital, health records, trends, settings, sign out
- [x] SupplementFormView — full CRUD (add/edit/delete) with form
- [x] Labs category filter pills (All, Flagged, Lipids, etc.)
- [x] FlowLayout for health profile pills
- [x] WorkoutDetailView upgrade — exercise log display + "add exercises" flow with library search
- [x] Water quick-add — progress ring, 8oz/16oz/24oz/custom, goal celebration, 7-day streak bars
- [x] Labs upload from iOS — DocumentPicker + multipart upload to /api/labs/parse + auto-save results
- [x] BrandColors.swift — centralized color system (all views use Brand.* references)
- [x] Brand bible color pass — Emerald Health palette applied (dark forest bg, emerald/sage accents, gold/amber secondary)

### Meal Photo Recognition (Session 9) — see Notion spec
- [x] POST /api/nutrition/analyze-meal — Claude Vision endpoint (Vercel)
- [x] MealAnalysisService.swift — image compression + API call
- [x] CameraPicker.swift — UIImagePickerController wrapper
- [x] MealAnalysisView.swift — photo capture, loading, results with editable macros, save
- [x] NutritionView "+" button → action sheet: Scan Meal Photo / Log Manually
- [x] Test end-to-end on device — working (camera → analyze → edit → save)
- [x] Scan available from 3 entry points: Today quick action, Activity "Log meal", NutritionView "+"
- [x] NSCameraUsageDescription + NSPhotoLibraryUsageDescription added to Info.plist
- [x] Fixed save 500 error — field names now match API (meal, mealType, proteinG, carbsG, fatG)
- [x] Loading animations, haptics polish — pulsing photo, rotating status messages, staggered item fade-in, haptics on capture/result/error
- [ ] Rate limiting UI (remaining scans badge)
- [ ] Web: file upload + results modal

### Onboarding (Session 9)
- [x] signUp method in AuthService
- [x] LoginView — Create Account / Sign In toggle
- [x] OnboardingView — 3-step wizard (name/sex/DOB, height/weight/goals, daily targets)
- [x] ContentView — profile check gate (skips onboarding if profile exists)
- [x] POST /api/profile + POST /api/targets routes (Vercel)
- [x] Camera + photo library permissions in project.yml
- [ ] Test onboarding with new account

### Sleep Detail (Session 10)
- [x] Sleep stages query (REM/Core/Deep/Awake) from HealthKit
- [x] Sleep heart rate query (avg/min/max + time series chart)
- [x] SleepDetailView — summary, stage bars, HR chart, 7-day weekly chart
- [x] Sleep card on Today taps to SleepDetailView instead of generic MetricDetailView
- [x] Added HKQuantityType(.heartRate) to HealthKit read permissions

### Bug Fixes (Session 10)
- [x] Double load on app launch — debounce TodayView onChange reload (3s threshold), skip scenePhase sync on first launch
- [x] Privacy policy requires login — added /privacy to public routes in web middleware

### UX Changes (Session 10)
- [x] Removed workout quick action from Today tab (redundant with Activity tab)
- [x] Settings: Privacy Policy + Web Dashboard open in-app via SafariViewController
- [x] Settings: Support mailto link added

### Bug Fixes (Session 9)
- [x] HealthKit sync not running — added enableBackgroundDelivery() + sync on launch + scenePhase handler
- [x] Pull-to-refresh "Network Error: cancelled" — removed duplicate loadData call
- [x] Resting HR not showing — query discrete metrics from 1 day earlier, attribute overnight sample to today
- [x] AI chat context expanded — now includes nutrition, water, SpO2, respiratory rate, distance, all labs, all supplements
- [x] Emerald palette pass — replaced 287 hardcoded Color(hex:) refs across 23 files with Brand.* colors

### Polish & Ship
- [x] App icon — placeholder emerald V (needs real design)
- [ ] Figma design file — 6/17 screens exported (rate limited), file: PbVZQjqKOHjBQ9K3seBFjt
- [x] Tab bar icons + active states
- [x] Loading skeletons / pull-to-refresh animations
- [x] Haptic feedback on key actions
- [x] Handle offline state gracefully
- [x] Card entrance animations (staggered fade-in, macro bar fill, press scale)
- [x] Empty state components (Dashboard, Workouts)
- [x] UI/UX audit → V2 redesign (3-tab progressive disclosure)
- [ ] App Store screenshots
- [ ] App Store description
- [x] Demo account for Apple reviewer (demo@vital.app / VitalDemo2026! — seed script at scripts/seed-demo-user.ts)
- [x] Upgrade to iOS 26 SDK — Swift 6, @Observable, Sendable models, deployment target 26.0
- [x] TestFlight — build uploaded, internal + external testing configured
- [x] Bundle ID registered (com.cesario.vital) + App Store Connect app record created
- [ ] Submit to App Store

### Web Dashboard (Session 11)
- [x] Terms of Service page — /terms
- [x] Public landing page — /home (feature grid, nav, footer)
- [x] Hide sidebar/nav on public pages (home, terms, privacy)
- [x] Force-deployed privacy page fix (was stale from Session 10)

### Backend Fixes (Session 3-4)
- [x] Bearer token support in createClient() — iOS app can now auth on all API routes
- [x] Oura OAuth credentials deployed to Vercel (OURA_CLIENT_ID, OURA_CLIENT_SECRET)
- [x] Oura OAuth scopes fixed — request all registered scopes (personal, daily, heartrate, workout, session, tag, spo2, email)
- [x] Supabase migration — added distance_miles, spo2, respiratory_rate columns to daily_metrics

### Additional HealthKit Data
- [x] Body weight (bodyMass) — syncs to weight_lbs column
- [x] Blood oxygen / SpO2 (oxygenSaturation) — syncs to spo2 column
- [x] Respiratory rate (respiratoryRate) — syncs to respiratory_rate column
- [x] Walking + running distance (distanceWalkingRunning) — syncs to distance_miles column
- [ ] Flights climbed (flightsClimbed)
- [ ] Stand hours (appleStandTime)

### Device Integrations (Future)
- [x] Oura Ring — OAuth flow on web dashboard (code-complete, credentials deployed)
- [ ] Oura Ring — test end-to-end with real ring
- [x] Oura Ring — "Connect Devices" link in iOS app MoreView/Settings
- [ ] Whoop — OAuth + sync (needed for runner beta tester)
- [ ] Garmin — OAuth + sync

### Workout Plans (Future)
- [ ] "Create plan on web dashboard" Safari link when no active plan
- [ ] Read-only plan detail view (tap plan card → full weekly schedule)
- [ ] Native AI plan generator (port multi-step chat questionnaire from web)

### Run-Specific Features (Future — for runner beta tester)
- [ ] Distance, pace, splits data from HealthKit
- [ ] Run detail view (map, splits table, pace chart)
- [ ] Weekly mileage tracking
