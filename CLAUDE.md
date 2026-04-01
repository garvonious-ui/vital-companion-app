# Vital — iOS Health Dashboard

## What This Is
Native iOS health dashboard + HealthKit sync. Dark-themed app with 4-tab layout: Dashboard (recovery ring, activity, trends), Workouts (logging, plans, set tracking), Nutrition (meal logging, macro tracking), More (supplements, AI chat, settings). Syncs Apple Health data automatically in the background.

Full V1 spec: @docs/ios-v1-spec.md

## Me
Louis Cesario (Lou), 34, Miami FL. Body recomp, lower cholesterol, ADHD management. Active user account: `cb5ac280` (garvonious@gmail.com).

## Tech Stack
- Swift, SwiftUI, iOS 17+
- HealthKit for health data access
- Swift Charts for sparklines/trends
- Supabase Swift SDK for auth
- URLSession for API calls
- BackgroundTasks framework for periodic sync

## Backend (already built — no changes needed)
- Base URL: https://vital-health-dashboard.vercel.app
- All routes require Bearer token (Supabase access token)
- Response format: `{ success: true, data: [...] }` or `{ success: false, error: "msg" }`
- Key routes: /api/metrics, /api/workouts, /api/nutrition, /api/targets, /api/profile, /api/supplements, /api/plans, /api/ai/chat, /api/ingest/apple-health
- Supabase project: ylwlxuexibrraztmxzew

## Critical Rules
- NEVER store health data on device beyond what's needed for sync
- All API calls authenticated via Bearer token from AuthService
- Dark theme ONLY — bg #0A0A0C, cards #141418, elevated #1C1C22
- Status colors: Green #00D68F, Amber #FFB547, Red #FF4757, Blue #00B4D8, Purple #8B5CF6
- Numbers use `.monospacedDigit()` modifier
- Handle HealthKit authorization denial gracefully
- Background sync must be battery-efficient
- Recovery score: HRV 50% + RHR 30% + Sleep 20% (see web docs/recovery-algorithm.md)

## Architecture
- Services: AuthService, HealthKitService, SyncService, APIService, NetworkMonitor
- Navigation: ContentView → auth gate → MainTabView (Dashboard, Workouts, Nutrition, More)
- Models: HealthData.swift (sync models), AppModels.swift (API response models)
- Components: HapticManager, SkeletonView, EmptyStateView, RecoveryRing, SparklineChart, MacroBar
- All views are SwiftUI, no UIKit (except HapticManager uses UIKit for UIImpactFeedbackGenerator)

## Gotchas (discovered Session 3)
- **Bearer token auth**: Web API routes use `@supabase/ssr` with cookies. iOS sends Bearer tokens. Fixed by updating `createClient()` in `src/lib/supabase.ts` to check Authorization header first.
- **Stale auth tokens**: Supabase Swift SDK restores expired sessions from local storage. `checkSession()` must call `refreshSession()` on startup, not just `client.auth.session`. Cache the token after sign-in.
- **API model field names**: Backend returns camelCase from data.ts (e.g. `hrvMs`, `restingHR`, `activeCalories`, `proteinG`). The Swift JSONDecoder uses `.convertFromSnakeCase` so model properties must match the camelCase keys exactly — NOT the database column names.
- **`#if DEBUG` localhost**: Don't use `#if DEBUG` for API URLs — debug builds run on physical devices which can't reach localhost. Always point to production.
- **Health Records entitlement**: `com.apple.developer.healthkit.access: health-records` is not supported by personal dev teams. Remove from entitlements AND project.yml before xcodegen.
- **XcodeGen**: project.yml `sources: - Vital` auto-includes all .swift files. After adding files, just run `xcodegen generate`. Make sure DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER match what's in the manually-edited pbxproj.
- **SyncLogEntry**: Defined in HealthData.swift. Don't duplicate in AppModels.swift.
- **Simulator names**: Xcode 16+ on macOS uses iPhone 17 Pro, not iPhone 16. Check available destinations.

## Reference Docs
- V1 spec: @docs/ios-v1-spec.md
- Build plan: @docs/build-plan.md
- Changelog: @docs/changelog.md (Sessions 1-2 archived in @docs/changelog-archive.md)
- Web app design system: /Users/loucesario/Health app/vital-health-dashboard/docs/design-system.md
- Recovery algorithm: /Users/loucesario/Health app/vital-health-dashboard/docs/recovery-algorithm.md
- Supabase schema: /Users/loucesario/Health app/vital-health-dashboard/docs/supabase-schema.md

## Commands
- Build: Cmd+B in Xcode
- Run: Cmd+R in Xcode (physical device required for HealthKit)
- Test: Cmd+U in Xcode

## Session Rules
- BEFORE starting work: read @docs/build-plan.md, @docs/changelog.md, and @docs/ios-v1-spec.md
- AFTER completing any feature: update build-plan.md and changelog.md
- When wrapping up: update both files, summarize for next session
- Test after each feature — don't build 5 things without verifying on device
