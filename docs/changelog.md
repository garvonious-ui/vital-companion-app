# Changelog — Vital Companion App

## 2026-04-08 — Session 21

### Food Database Search (USDA FoodData Central)
- **Backend**: `src/lib/fatsecret.ts` — USDA API client with search + food detail (OAuth token caching)
- **GET /api/nutrition/search?q=chicken** — proxies USDA foods.search, returns name, brand, macros, serving
- **GET /api/nutrition/food?id=12345** — proxies USDA food detail with serving options
- **FoodSearchView.swift** (new) — search bar with 300ms debounce, result list showing macros per serving
- **Serving picker** — tap result to see serving options (e.g. 100g, 1 breast, 1 oz), quantity multiplier ±0.5, macro preview scales proportionally
- **"Add to Meal Log"** — pre-fills MealFormView with selected food's name, calories, protein, carbs, fat
- **MealFormView** — added prefill parameters (prefillName, prefillCalories, prefillProtein, prefillCarbs, prefillFat)
- **No results fallback** — "Log manually instead" link opens MealFormView with search text as name
- **Available from all 3 entry points**: Today quick action, Activity log meal, Nutrition "+" button
- FatSecret initially tried but requires IP whitelisting (incompatible with Vercel), switched to USDA which is free with no restrictions
- Applied for FatSecret Premium (free tier) — will swap if approved

### Oura Dev Account
- New Oura application approved with ten-user limit lifted
- New credentials (Client ID + Secret) deployed to Vercel
- In-app OAuth flow ready for any Oura user

### Files Created
- `src/lib/fatsecret.ts` (web dashboard) — USDA FoodData Central client
- `src/app/api/nutrition/search/route.ts` (web dashboard)
- `src/app/api/nutrition/food/route.ts` (web dashboard)
- `Vital/Views/Nutrition/FoodSearchView.swift`

### Files Modified (iOS)
- `Vital/Views/Nutrition/MealFormView.swift` — prefill parameters + onAppear logic
- `Vital/Views/Nutrition/NutritionView.swift` — "Search Food Database" in action sheet + sheet
- `Vital/Views/Today/TodayView.swift` — food search state + action sheet + sheet
- `Vital/Views/Activity/ActivityView.swift` — food search state + action sheet + sheet

### Bugs Found
- **FatSecret IP whitelisting** — API rejects requests from Vercel's dynamic IPs (error code 21). No workaround without Premier plan or fixed-IP proxy. Switched to USDA.

### Decisions
- USDA FoodData Central over FatSecret — free, no IP restrictions, comprehensive (22k+ results for "chicken")
- Same API response format so iOS code works with either backend
- FatSecret Premium applied for — easy swap if approved (one file change)
- Food search added to all meal logging entry points for consistent UX

### TestFlight
- Build 17 uploaded

### Status
- Food database search: **Complete and deployed**
- Oura dev account: **Approved**
- FatSecret Premium: **Applied, pending**

### What's Next
1. **App Store screenshots + description**
2. **Submit to App Store**
3. **Swap to FatSecret if approved**
4. **Garmin integration** (if needed)

## 2026-04-06/07 — Sessions 19-20

### Manual Sleep Logging
- Sleep card on Today tab shows "Tap to log" when no sleep data
- Alert prompts for hours slept, saves via PATCH /api/metrics
- Recovery score recalculates immediately after saving
- Backend: added `sleepHours` to PATCH /api/metrics handler

### Nutrition Improvements
- Added "Drink" as meal type (MealFormView, MealAnalysisView, NutritionView)
- Drink icon (mug.fill) in nutrition list grouping
- Meal scan detected items now fully editable (name, portion, cal/protein/carbs/fat per item)
- Items can be removed with X button before saving

### AI Actions
- AI can now suggest data updates mid-conversation
- System prompt instructs AI to output `[ACTION:type {...}]` tags
- Supported actions: `add_supplement`, `log_water`, `log_sleep`
- iOS parses action tags from streamed response, strips from displayed message
- Inline confirmation card appears below AI response ("Yes, add it" / "No thanks")
- On confirm: calls existing API endpoints (POST /supplements, PATCH /metrics)
- Success/failure feedback with haptics

### Oura In-App OAuth
- **GET /api/devices/oura/connect-mobile** (new) — takes Bearer token, embeds user ID in OAuth state
- **Callback updated** — detects `mobile:` state prefix, uses service role client to store tokens
- Returns HTML success page for mobile flow ("Oura Connected! You can close this window.")
- **DeviceSelectionView** — Oura button now opens ASWebAuthenticationSession with OAuth flow
- OuraAuthPresenter for presentation context
- New Oura app created and approved (ten-user limit lifted)
- New credentials deployed to Vercel

### Whoop Integration
- Whoop syncs via HealthKit — no API integration needed
- Added Whoop button to DeviceSelectionView (triggers HealthKit permissions)
- Subtitle: "Enable Apple Health sharing in your Whoop app first, then connect here"
- Confirmed working with real Whoop user

### Oura Dev Account
- First app rejected twice (no connected users detected)
- Created new application with proper description, URLs, and scopes
- Teresa connected via new app's OAuth
- Approved with ten-user limit lifted

### Backend Fixes
- Fixed Supabase type errors in cron route (cast to `any` for dynamic updates)
- Fixed CRON_SECRET whitespace issue blocking all Vercel deploys
- Multiple force deploys needed to get routes picked up

### Files Created
- `src/app/api/devices/oura/connect-mobile/route.ts` (web dashboard)

### Files Modified (iOS)
- `Vital/Views/DeviceSelectionView.swift` — Oura OAuth, Whoop button, OuraAuthPresenter
- `Vital/Views/Today/TodayView.swift` — manual sleep logging (tap to log, saveSleep)
- `Vital/Views/Nutrition/MealAnalysisView.swift` — editable items, drink type
- `Vital/Views/Nutrition/MealFormView.swift` — drink type
- `Vital/Views/Nutrition/NutritionView.swift` — drink type + icon
- `Vital/Views/More/ChatView.swift` — AI action parsing, confirmation cards, execution

### Files Modified (Web Dashboard)
- `src/lib/ai-context.ts` — action system in system prompt
- `src/app/api/devices/oura/callback/route.ts` — mobile flow support
- `src/app/api/metrics/route.ts` — sleepHours in PATCH handler
- `src/app/api/cron/sync-devices/route.ts` — type error fixes

### TestFlight
- Builds 15, 16 uploaded

### Decisions
- Whoop doesn't need API integration — HealthKit bridge is sufficient
- Oura OAuth in-app uses ASWebAuthenticationSession (not SFSafariViewController)
- AI action tags parsed client-side from streamed text (no native Claude tool_use)
- New Oura app created rather than fighting rejected app resubmission
- Vercel Hobby plan cron limitations accepted — on-demand sync from iOS is better UX anyway

### Status
- AI Actions: **Complete and tested**
- Oura in-app OAuth: **Complete, deployed**
- Oura dev account: **Approved**
- Whoop: **Working via HealthKit**
- Manual sleep: **Complete**
- Nutrition editable items: **Complete**
- Drink meal type: **Complete**

### What's Next
1. **App Store screenshots + description**
2. **Test onboarding with new account**
3. **Submit to App Store**
4. **Garmin integration** (if needed)
5. **Recovery score weighting by device source**

## 2026-04-04/05 — Sessions 17-18

### True Midnight Color Palette
- Deep ink-blue surfaces (#080C1E bg, #111530 card, #1A1E40 elevated)
- Periwinkle accent (#8B8AE5), soft gold primary/optimal (#C9A84C)
- Lavender text tones (#D8D8F0, #8888B0, #555578)
- Gold → periwinkle gradients for avatar + AI Insights button

### Device Onboarding Flow
- **DeviceSelectionView.swift** (new) — "How do you track?" screen after login
- Options: Apple Watch (→ HealthKit), Oura Ring (→ skip to app), Just iPhone (→ optional HealthKit), Skip
- Device choice saved to UserDefaults, restored on subsequent launches
- Existing HealthKit-authorized users auto-set to Apple Watch (no re-prompt)
- MainTabView conditionally skips HealthKit sync for non-Apple Watch users

### Full App Audit — 7 Fixes
- **TodayView scenePhase** — now refreshes data on every foreground return (was only on error)
- **TodayView pull-to-refresh** — directly reloads + re-animates (was blocked by 3s debounce)
- **ActivityView** — added scenePhase handler for foreground refresh + removed dead activePlanCard code
- **APIService** — cancelled requests handled silently (new `.cancelled` case, returns nil errorDescription)
- **SleepDetailView** — replaced hardcoded Color(hex:) with Brand.secondary/accent, ignores CancellationError
- **ProfileView** — ignores cancelled errors on avatar upload
- **SettingsView/SupplementsView** — removed "web dashboard" references, updated to in-app messaging

### Oura On-Demand Sync
- iOS app calls `POST /devices/oura/sync` on launch and foreground return for Oura users
- Replaces cron approach (Vercel Hobby plan only allows daily crons)
- Fixed Oura API date filter bug — sleep sessions not returned with date params but available without them
- Fix: merged unfiltered `/sleep` response with date-filtered response (deduped by session id)
- Cron route also updated with same fix + HR fallback endpoint

### Oura Dev Account
- Teresa connected via OAuth on web dashboard (proper "connected member")
- Resubmitted Oura app for review with OAuth-connected user
- Teresa's password reset for web dashboard access

### Build Plan Updates
- Added "Nutrition Improvements" section (drinks, editable scan results)
- Checked off device onboarding items (5 of 7 done)
- Updated recurring sync section (on-demand replaces cron)

### Files Created
- `Vital/Views/DeviceSelectionView.swift`

### Files Modified (iOS)
- `Vital/BrandColors.swift` — True Midnight palette
- `Vital/Views/ContentView.swift` — device selection gate, Oura sync trigger, auto-detect existing users
- `Vital/Views/Today/TodayView.swift` — scenePhase fix, pull-to-refresh fix, cancelled error handling
- `Vital/Views/Activity/ActivityView.swift` — scenePhase handler, removed dead code, cancelled handling
- `Vital/Services/APIService.swift` — `.cancelled` error case
- `Vital/Views/Today/SleepDetailView.swift` — Brand colors, CancellationError handling
- `Vital/Views/Profile/ProfileView.swift` — cancelled error handling on upload
- `Vital/Views/SettingsView.swift` — removed "web dashboard" text
- `Vital/Views/More/SupplementsView.swift` — updated empty state text
- `Vital/Views/LoginView.swift` — name still "Vital" (Vesper reverted)
- `Vital/Views/OnboardingView.swift` — name still "Vital"
- `Vital/Views/PermissionsView.swift` — name still "Vital"

### Files Modified (Web Dashboard)
- `src/app/api/devices/oura/sync/route.ts` — unfiltered sleep merge fix
- `src/app/api/cron/sync-devices/route.ts` — HR fallback, unfiltered sleep merge, daily_sleep fallback
- `vercel.json` — cron limited to daily (Hobby plan)

### Bugs Found
- **Vercel Hobby plan** — only allows 1 cron/day, not every 2 hours. Our cron was never running. Switched to on-demand sync from iOS.
- **CRON_SECRET whitespace** — env var had leading/trailing whitespace, rejected by Vercel deploy
- **Oura API date filter bug** — `/sleep?start_date=2026-04-05` returns 0 sessions, but `/sleep` (no params) returns today's session. Timezone mismatch in Oura's API.
- **Oura sleep sessions lag** — sleep session details appear in API much later than daily scores. Personal access token and OAuth token return identical results.

### Decisions
- On-demand sync from iOS instead of cron (better UX, no Hobby plan limit)
- Vesper name reverted to Vital (not sold on it yet)
- True Midnight palette kept (user approved darker bg)
- Vercel Pro plan not needed — on-demand sync works without crons
- Oura personal access tokens work fine alongside OAuth for data access

### TestFlight
- Builds 12, 13, 14 uploaded across sessions

### Status
- True Midnight palette: **Complete**
- Device onboarding: **Complete (5/7 items)**
- App audit fixes: **Complete (7/7)**
- Oura sync: **Working via on-demand from iOS**
- Oura dev account: **Resubmitted for review**

### What's Next
1. **App Store screenshots + description**
2. **Test onboarding with new account**
3. **Submit to App Store**
4. **Verify Teresa's Oura data showing in app after build 14**
5. **Oura dev account approval** — waiting on Oura review

*Sessions 3-16 archived in [changelog-archive.md](changelog-archive.md)*
