# Changelog — Vital Companion App

## 2026-04-09 — Session 22

### FatSecret Premier Free Swap (USDA → FatSecret)
- **FatSecret Premier Free approved** — barcode scanning, autocomplete search, food categories, US data set
- **`src/lib/fatsecret.ts` rewritten** — real FatSecret OAuth 2.0 client (was a USDA client misnamed)
  - `client_credentials` grant against `https://oauth.fatsecret.com/connect/token`
  - Per-instance access token cache with 60s expiry buffer
  - `foods.search` + `food.get.v4` against `https://platform.fatsecret.com/rest/server.api`
  - Pre-formatted FatSecret `food_description` parsed for numeric macros (regex)
  - Same exported interfaces (`FoodSearchResult`, `FoodDetail`, `FoodServing`) so iOS + routes need zero changes
- **IP whitelist** — added `0.0.0.0/0` and `::/0` in the OAuth 2.0 portal section (separate whitelist from OAuth 1.0)
- **Vercel env vars** — `FATSECRET_CLIENT_ID` + `FATSECRET_CLIENT_SECRET` rotated to OAuth 2.0 values, deployed via CLI
- **Live test verified** — real Chipotle/Kirkland brand matches returned, food detail with serving options works

### Multi-Item Meal Cart
- **`MealCartItem` struct** — staged item with already-scaled macros + serving description
- **FoodSearchView cart state** — `@State var mealCart: [MealCartItem]`
- **"Add to Meal" button** in serving picker (was "Add to Meal Log") — appends to cart, returns to results to add more, label updates to "Add Another (N so far)"
- **Sticky cart bar** at bottom via `safeAreaInset` — count + total cal + total protein + Review arrow, only visible when cart non-empty
- **Cancel guard** — confirmation dialog if user dismisses with items in cart
- **`MealReviewView`** (new) — full review/save sheet:
  - Meal type chips (defaults to Lunch, capitalized)
  - Editable meal name (auto-composed: "Brand: A, B, C" if all items share a brand, else "A, B, C", with "+ N more" if >3 items)
  - Item list with delete buttons (per-row)
  - Summed totals (cal/protein/carbs/fat)
  - "Save Meal" button → POSTs one row with composed name + summed macros + per-item breakdown stored in `notes` field

### Three Layered Nutrition Save Bugs (chain)
1. **Encoder snake_case mismatch** — `APIService` uses `.convertToSnakeCase`, but `/api/nutrition` reads camelCase. So `mealType`/`proteinG`/`carbsG`/`fatG` were silently dropped → DB rows had NULL for those fields → "No meals logged" empty state. **Fix**: `MealFormView.save()` now uses `postRaw` with raw `[String: Any]` dict, matching the pattern already used by `MealAnalysisView` and most of the codebase. Old broken `NutritionLogBody` struct kept with a warning comment.
2. **Meal type case mismatch** (hidden by bug #1) — DB CHECK constraint requires capitalized values (`'Breakfast'`, `'Lunch'`, ...). iOS sent lowercase `"lunch"`. With bug #1 fixed, the constraint started rejecting inserts. **Fix**: capitalized `mealTypes` array + default in `MealFormView`, edit-path normalizes via `.capitalized` for legacy data. Also: `Drink` was missing from the constraint entirely — applied migration `add_drink_to_meal_type_check`.
3. **APIError display bug** — `error.localizedDescription` showed `"error 8"` instead of the real serverError message. **Fix**: `NutritionView` now reads `(error as? APIError)?.errorDescription` directly to bypass NSError bridging. Also: `serverError` errorDescription now includes a 120-char body snippet so future failures actually tell us what went wrong.

### UX Fixes (FoodSearchView)
- **Stale prefill on first open** — `.sheet(isPresented:)` was reading `@State` prefill values captured in the closure before they updated. Switched to `.sheet(item: $mealPrefill)` with `MealPrefill: Identifiable` struct so the closure receives fresh values atomically.
- **Stale food detail when typing new search** — `selectedFood`/`selectedServing` now cleared in `onChange(of: searchText)`.
- **FoodSearchView didn't auto-close after save** — added optional `onSaved: (() -> Void)?` callback to `MealFormView`, fired on save success before dismiss; FoodSearchView wires it to bubble up through `self.onSaved?()` and dismiss itself.

### Backend Error Handler Fix
- **`/api/nutrition` route** — `String(error)` on a Supabase PostgrestError stringified to `"[object Object]"`, masking the real constraint violation. Now extracts `.message` from Error-shaped objects. This is what surfaced the meal_type case mismatch — without this fix we'd still be guessing.

### Changelog Maintenance
- **Archived sessions 6-16** to `changelog-archive.md` — main changelog was 60.7k chars, exceeding Claude Code's 40k auto-load threshold. Now back under limit.

### Git Author Fix
- iOS repo had no `user.email` per-repo config → commits were authored by `loucesario@MacBook-Air-8.local` (auto-generated hostname). Set per-repo config to `lou.cesario92@gmail.com` and amended the two unpushed commits via `git rebase HEAD~2 --exec "git commit --amend --reset-author --no-edit"`.

### Files Created
- (none — extended existing files)

### Files Modified (iOS)
- `Vital/Views/Nutrition/FoodSearchView.swift` — `MealCartItem`, `MealPrefill`, cart state, sticky cart bar, `addCurrentFoodToCart`, `MealReviewView`, sheet-item fix, stale-detail fix
- `Vital/Views/Nutrition/MealFormView.swift` — `postRaw` save, `onSaved` callback, capitalized mealTypes + default + edit normalization, PATCH path uses id-in-body
- `Vital/Views/Nutrition/NutritionView.swift` — APIError-aware error display
- `Vital/Models/AppModels.swift` — comment on `NutritionLogBody` warning future devs not to use it
- `Vital/Services/APIService.swift` — verbose `serverError` description with body snippet
- `docs/changelog.md` — archive split + this entry
- `docs/changelog-archive.md` — full sessions 6-16 added
- `docs/build-plan.md` — Session 22 checkboxes

### Files Modified (Web Dashboard)
- `src/lib/fatsecret.ts` — full rewrite as real FatSecret OAuth 2.0 client (was USDA in disguise)
- `src/app/api/nutrition/route.ts` — error handler extracts `.message` from Error objects

### Database Migrations
- `add_drink_to_meal_type_check` — extends `nutrition_log_meal_type_check` to allow `'Drink'`

### Backend Deployments
- FatSecret OAuth 2.0 client + nutrition error handler force-deployed via `vercel --prod`
- Vercel env vars updated via CLI: `FATSECRET_CLIENT_ID`, `FATSECRET_CLIENT_SECRET` (rotated to OAuth 2.0 values)

### Bugs Found
- **CodingKeys + `.convertToSnakeCase` myth** — explicit `CodingKeys` raw values do NOT bypass JSONEncoder's `keyEncodingStrategy`. Verified empirically when first attempted fix didn't work. Only way to encode camelCase with that encoder is to use a different encoder (or `JSONSerialization` via `postRaw`).
- **Long-standing manual meal log rows have null `meal_type`** — every manual meal logged via `MealFormView` since Session 9 has had nulls because of the encoder bug. Meal scans (via `MealAnalysisView`) worked fine because they always used `postRaw`.
- **`QuickLogView` and `WorkoutDetailView` likely affected too** — they're the only other places still using `apiService.post(_:body:)`. Not investigated this session, but worth a follow-up audit.
- **Long bash commands wrap in Claude Code prompt input** — when guiding the user through `git config` commands, paths over ~80 chars wrap, breaking the command. Workaround: drop `cd` and rely on cwd, or use shorter commands.

### Decisions
- **Single-row schema for multi-item meals** (not a child `nutrition_items` table) — ships in one session vs ~4 hours, preserves per-item breakdown in `notes` field for context. Can migrate to a proper child table later if needed.
- **`MealReviewView` lives in same file as `FoodSearchView`** — tightly coupled, no reuse elsewhere, keeps file count down.
- **Default review meal name auto-composed** — smart brand-aware compose ("Chipotle: Chicken, Rice"). User can edit before save.
- **Cart Cancel guard** — confirmation dialog only if cart non-empty.
- **OAuth 2.0 over OAuth 1.0** — same Consumer Key/Secret work for both on FatSecret's portal, but OAuth 2.0 is way simpler (no HMAC-SHA1 request signing). User had to enable OAuth 2.0 separately + reset its Client Secret since OAuth 2.0 has its own (separate from OAuth 1.0) secret + IP whitelist.
- **Don't push yet** — local commits sit on `main`, will push after Session 22 wrap is committed and FatSecret secret is rotated.

### Status
- FatSecret Premier Free: **Complete and deployed**
- Multi-item meal cart: **Complete, tested on device**
- Nutrition save bugs: **All three fixed and tested**
- Backend error handler: **Improved**
- DB migration: **Applied to prod**
- Git history: **Author fixed for iOS repo**

### What's Next
1. **Rotate FatSecret OAuth 2.0 Client Secret** — Lou pasted current secret in chat; rotate before push for safety
2. **Push both repos to GitHub** — `vital-health-dashboard` (1 commit ahead) + `vital-companion-app` (3 commits ahead, all with correct author)
3. **TestFlight build 18** — bump build number, archive in Xcode, upload (multi-item meals + bug fixes worth shipping to testers)
4. **Audit `QuickLogView` and `WorkoutDetailView`** for the same encoder bug
5. **App Store screenshots + description**
6. **Submit to App Store**

### Post-Wrap Addendum (still Session 22)

After the wrap commit, we kept going and shipped the rest of the queue:

**FatSecret OAuth 2.0 secret rotation**
- Old secret (`62b9be09...`) was in chat history, rotated to new value (`2bf6f4cc...`)
- Vercel `FATSECRET_CLIENT_SECRET` updated via CLI, redeployed
- Verified token endpoint with new creds before redeploying

**Both repos pushed to GitHub**
- `vital-health-dashboard`: `d590062..99fbc4f` (1 commit)
- `vital-companion-app`: `377661d..a446034` (3 commits, all with correct author)

**TestFlight build 18 uploaded**
- Bumped `CURRENT_PROJECT_VERSION` to 18 in `project.yml`
- `xcodegen generate` + `xcodebuild archive` (Release config)
- Copied archive into `~/Library/Developer/Xcode/Archives/` so Organizer picks it up
- Uploaded via Xcode Organizer (App Store Connect API access blocked by Apple permission gate — needs "Request Access" in Users and Access → Integrations, deferred to next session)
- Build 1.0.0 (18) confirmed uploaded

**Latent bug fixed: Info.plist version templating**
- `Vital/Info.plist` had `CFBundleShortVersionString` and `CFBundleVersion` hardcoded as literal `"1.0"` and `"1"` instead of using `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` templates like the other standard keys (`PRODUCT_BUNDLE_IDENTIFIER`, `EXECUTABLE_NAME`, etc.) in the same file
- Caught this when first attempted archive came out as `1.0 (1)` instead of `1.0.0 (18)` despite the project.yml bump
- How build 17 ever uploaded is a mystery — best guess is someone manually edited the literal value before each archive and it got reset somewhere along the way
- Fixed by switching both keys to template variables. Future bumps in `project.yml` now propagate automatically

**Post-wrap commits**
- `f4e2b1c` — TestFlight build 18 + fix Info.plist version templating (pushed)

### Final Status (end of Session 22)
- **TestFlight build 18**: uploaded, processing in App Store Connect
- **All planned work shipped**
- **Both repos clean and pushed** (origin/main matches local main)

### What's Next (real, for next session)
1. **Test build 18 on device** once App Store Connect finishes processing
2. **Apple's "Request Access" for App Store Connect API** — click the button so future TestFlight uploads can be fully scriptable from CLI (5-minute setup)
3. **Audit `QuickLogView` + `WorkoutDetailView`** for the same `apiService.post(_:body:)` snake_case bug that bit `MealFormView`
4. **App Store screenshots + description**
5. **Test onboarding with a fresh account**
6. **Submit to App Store**

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
