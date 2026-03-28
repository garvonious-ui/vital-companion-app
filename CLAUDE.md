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
- Services: AuthService (existing), HealthKitService (existing), SyncService (existing), APIService (new — generic REST client)
- Navigation: ContentView → auth gate → TabView (Dashboard, Workouts, Nutrition, More)
- Models: HealthData.swift (sync models, existing), AppModels.swift (API response models, new)
- All views are SwiftUI, no UIKit

## Reference Docs
- V1 spec: @docs/ios-v1-spec.md
- Build plan: @docs/build-plan.md
- Changelog: @docs/changelog.md
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
