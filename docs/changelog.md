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
