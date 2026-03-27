# Build Plan — Vital Companion App

## Phase 1 — Core Sync
- [ ] Create Xcode project with HealthKit + Background Modes capabilities
- [ ] Add Supabase Swift SDK dependency (Swift Package Manager)
- [x] Build LoginView (email + password, matches web app dark theme)
- [x] Build AuthService (sign in, sign out, session persistence)
- [x] Build HealthKitService (permission request, data queries)
- [x] Build PermissionsView (request HealthKit access, explain each metric)
- [x] Build SyncService (format data, POST to ingest API)
- [x] Build SyncStatusView (last sync time, manual sync button, sync log)
- [x] Wire up: login -> permissions -> auto-sync
- [ ] Test on physical device with real Apple Watch data
- [x] Update backend ingest route to accept Supabase access tokens

## Phase 2 — Background Sync
- [x] Register HealthKit background delivery for all metric types
- [x] Register BGTaskScheduler for periodic sync fallback
- [x] Handle app lifecycle (scenePhase changes trigger sync)
- [x] Save/restore lastSyncDate in UserDefaults
- [ ] Test background sync (kill app, generate health data, verify sync)

## Phase 3 — Polish & Ship
- [ ] Error handling (network failures, expired tokens, HealthKit denied)
- [ ] Retry logic with exponential backoff
- [x] Settings view (sign out, sync frequency, debug log)
- [ ] App icon (Vital gradient — blue to purple)
- [ ] Launch screen (Vital logo)
- [ ] Privacy policy page (required for HealthKit apps)
- [ ] App Store screenshots
- [ ] Submit to App Store
