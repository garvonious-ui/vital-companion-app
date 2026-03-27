# Vital Companion App — iOS

## What This Is
Native iOS companion app for Vital Health Dashboard. Syncs Apple Health data (workouts, HRV, RHR, steps, sleep, VO2 max, active calories, exercise minutes) to the Vital backend automatically via background delivery.

## Tech Stack
- Swift, SwiftUI, iOS 17+
- HealthKit for health data access
- Supabase Swift SDK (@supabase-community/supabase-swift) for auth
- URLSession for API calls to Vital backend
- BackgroundTasks framework for periodic sync

## Backend (already built)
- API endpoint: POST /api/ingest/apple-health
- Auth: Supabase access token as Bearer token
- Base URL (prod): https://vital-health-dashboard.vercel.app
- Base URL (dev): http://localhost:3000
- Supabase project: ylwlxuexibrraztmxzew

## Critical Rules
- NEVER store health data on device beyond what's needed for sync
- Request ONLY the HealthKit permissions we actually use
- Handle HealthKit authorization denial gracefully
- Background sync must be battery-efficient (batch reads, minimal network calls)
- All API calls must be authenticated (Supabase session token)
- Dark theme to match web app (bg #0A0A0C, cards #141418)

## Commands
- Build: Cmd+B in Xcode
- Run: Cmd+R in Xcode (requires simulator or physical device)
- Test: Cmd+U in Xcode

## Session Rules
- BEFORE starting work: read @docs/build-plan.md and @docs/changelog.md
- AFTER completing any feature: update both files
- When wrapping up: update build-plan.md, write changelog entry, summarize
