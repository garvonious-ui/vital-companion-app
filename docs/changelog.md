# Changelog — Vital Companion App

## 2026-04-14 — Session 24

Focused bug-fix session. Three user-reported issues from daily use of build 19, all fixed, tested on device, shipped as build 20 to TestFlight.

The user's exact report, in their words:
> "Can we add the food database after a user takes a photo of a meal? when it doesnt get it correctly it makes it difficult to update the meal. Also after a night of sleep I am noticing that when I open the app it doesnt automatically refresh, I need to pull to refresh, then switch to another page and then go back to Today for the data to display. Also, I noticed that when you manually quick log a workout that you cannot edit the calories or duration, we need to make that editable."

### Per-item food database swap in meal scan results

Editable-item rows already existed from Session 9, but there was no way to reach the food database from the MealAnalysisView scan results screen. If Claude Vision saw "grilled chicken" as "rotisserie pork", the user had to manually type the correct name and correct all four macro fields.

**Design fork resolved via AskUserQuestion:** whole-meal swap vs per-item swap vs both. User chose **per-item** — best when the scan gets most items right but one wrong, which matches the common failure mode.

**Implementation** (`Vital/Views/Nutrition/MealAnalysisView.swift`):
- New `ItemSwapTarget: Identifiable` wrapper with `UUID` id and Int index. Using `.sheet(item:)` instead of `.sheet(isPresented:)` + separate index state — same Session 22 atomic-capture pattern that fixed the meal edit stale-prefill bug.
- New magnifying-glass button (`magnifyingglass.circle.fill`, Brand.accent) added to each `editableItemRow` HStack between the name TextField and the existing X delete button. Spacing bumped to 10pt.
- `.sheet(item: $swapTarget)` presents `FoodSearchView(date:onSaved:onFoodSelected:)` in **selection mode** (the onFoodSelected parameter was added in Session 23 for the meal edit flow — zero FoodSearchView changes needed).
- New `applyFoodSelection(_:toItemAt:)` helper — replaces the item's name with the composed "\(brand) \(foodName)" string when brand is present, otherwise just foodName. Converts `MealSelection`'s Double grams to Int via `.rounded()`. `MealItem` uses Int macros so the conversion is lossy but sub-gram precision doesn't matter and the UI already displays integers.
- New `recomputeTotalsFromItems()` helper — sums the items array into the top-level `calories`/`protein`/`carbs`/`fat` TextFields. Called after every swap. **Also called after the X-delete** — previously the X delete was cosmetic-only because items were displayed but not summed back into the saved totals. Now the top-level totals that actually get saved always match the user's line-item edits.
- The swap does NOT touch the top-level `mealName` field (still "Lunch" or whatever). Only line items change. Portion text is not updated (FoodSearchView's serving picker handles scaling before the callback fires).

### Today cold-launch refresh race

User reported that after overnight idle, reopening the app showed stale data until pull-to-refresh + tab-switch-and-back. Exploration via an Explore agent traced the exact code path and found a race between `MainTabView.task` (which runs `runBackgroundSync()` then bumps `refreshCoordinator.refreshToken`) and `TodayView.task` (which runs `loadData()` in parallel and sets `lastLoadTime = Date()`).

**The bug chain:**
1. Cold launch → both `.task`s fire in parallel
2. `TodayView.task` → `await loadData()` → hits `/metrics` BEFORE HealthKit has pushed today's data → returns yesterday's data → sets `lastLoadTime = Date()`
3. `MainTabView.task` → `await runBackgroundSync()` → HealthKit pushes today's data to Supabase → `refreshCoordinator.requestRefresh()` bumps token
4. `TodayView.onChange(of: refreshToken)` fires → checks `Date().timeIntervalSince(lastLoadTime) > 3` → **fails** (lastLoadTime was just set 1-2s ago) → **silently skips the reload**
5. Result: Today renders yesterday's data and never gets the fresh-data signal. User has to pull-to-refresh manually.

The 3-second debounce was added in Session 10 to prevent double-fire between `.task` and the post-sync bump. It fixed the symptom at the time but introduced this latent bug: the bump and the task are always within a few seconds of each other, so the bump is always filtered out.

**Fix (TodayView, ActivityView, ProfileView):**
Replaced the `.task { loadData() }` + `.onChange(refreshToken)` + 3-second manual debounce pattern with a single `.task(id: refreshCoordinator.refreshToken)` modifier on all three tabs.

```swift
.task(id: refreshCoordinator.refreshToken) {
    await loadData()
    triggerAnimations()
}
```

`.task(id:)`:
- Fires on first appearance with the current token value
- Re-fires on every `id` change, cancelling the previous task cleanly
- Removes the race — the post-sync bump is guaranteed to re-trigger loadData with no debounce gate

Also removed the `lastLoadTime` state var and all call sites (including `syncAndRefresh()` and `saveSleep()` in TodayView) since they're now dead.

Two loads on cold launch are expected and acceptable:
1. First `.task(id:)` fires with `refreshToken = 0` on view appear → possibly stale data (before HK sync)
2. After MainTabView bumps to 1 post-sync → re-fires with fresh data

The existing first-load-vs-refresh branching in `loadData()` (`let firstLoad = metrics.isEmpty`) means the second load doesn't flash a skeleton — the first load's data stays visible until the second load replaces it.

### Edit Quick Log / Manual workouts

`WorkoutDetailView` was entirely read-only for stats, so a mis-entered Quick Log (wrong calories or duration) could only be corrected via delete + re-add. Scope discipline: only Manual/Quick Log workouts editable — Apple Watch / Oura / Whoop / Garmin stay read-only because their values are authoritative from the source device (same design fork resolved via AskUserQuestion).

**Backend** (`vital-health-dashboard`):
- New `updateWorkout(userId, id, patch)` in `src/lib/data.ts` — builds a sparse `Record<string, unknown>` from the patch fields (`workoutName` → `workout_name`, etc.), runs `.update().eq("id", id).eq("user_id", userId)`. Returns void. `source` and heart rate fields are intentionally not patchable — `source` stays authoritative from the creation path, HR only exists on Apple Watch workouts which aren't editable anyway.
- New `PATCH /api/workouts?id=...` handler in `route.ts` — mirrors the DELETE handler's shape (query param for id, body for patch fields). Session 22/23 `.message` error extraction pattern — no more `[object Object]` masking Supabase errors.
- Deployed to Vercel prod (`target: "production"`, `readyState: "READY"`).

**iOS API layer** (`Vital/Services/APIService.swift`):
- Extended `patchRaw(_:jsonData:)` to accept an optional `queryItems: [URLQueryItem]? = nil` parameter. Matches the existing DELETE signature. Backwards compatible — existing call site in TodayView's `saveSleep()` passes no queryItems.

**iOS WorkoutDetailView** (`Vital/Views/Workouts/WorkoutDetailView.swift`):
- Converted `let workout: Workout` to `@State private var currentWorkout: Workout` seeded from an explicit `init(workout:onDeleted:onUpdated:)`. This lets the edit flow mutate the detail view's state in place after a successful PATCH — the user sees the updated values immediately without waiting for a parent reload.
- All 14 body references renamed from `workout.` to `currentWorkout.` via `Edit(replace_all: true)`. `AddExerciseView` uses its own `workoutDate: String` let param and was untouched.
- New `isEditable` computed: `source == "Manual" || source == "Quick Log"`.
- New conditional "Edit" toolbar button (trailing, before "Done") gated on `isEditable`. Apple Watch / Oura / Whoop / Garmin workouts show only the Done button.
- New `onUpdated: ((Workout) -> Void)?` callback prop.
- New `.sheet(isPresented: $showEditSheet)` presenting `WorkoutEditView`. On save: `currentWorkout = updated; onUpdated?(updated)`.

**New `WorkoutEditView` struct** (same file, below `AddExerciseView`):
- Mirrors `QuickLogView`'s 8-option type grid + name/duration/calories/notes fields. Same `workoutTypes` array with the canonical DB values from Session 23's `expand_workout_types` migration.
- Init seeds all `@State` text fields from the passed Workout.
- `save()` builds a raw `[String: Any]` body (encoder-safe — no `.convertToSnakeCase` trap from Session 22) with backend camelCase field names. Calls `apiService.patchRaw("/workouts", jsonData:, queryItems: [URLQueryItem(name: "id", value: workout.id)])`.
- Constructs the updated `Workout` locally from the old one + the patch fields. The server returns `{success: true}` with no data — returning the Supabase row directly would require another snake_case→camelCase mapping layer. Simpler: since iOS already has the old object + knows which fields changed, it can synthesize the new one without a round trip.
- Calls `onSaved(updated)` then `dismiss()`.
- Error state via `(error as? APIError)?.errorDescription ?? error.localizedDescription` (Session 23 pattern — exposes real server errors, not "error 8").

**iOS ActivityView** (`Vital/Views/Activity/ActivityView.swift`):
Wired `onUpdated` alongside the existing `onDeleted` in the `.sheet(item: $selectedWorkout)` closure. On update, finds the row in `workouts` by id and replaces it in place. No refetch, no tab-wide refresh, no RefreshCoordinator bump — the local array update is sufficient.

### Files Created
- (none — all extensions to existing files)

### Files Modified (iOS)
- `Vital/Services/APIService.swift` — `patchRaw` accepts optional `queryItems`
- `Vital/Views/Nutrition/MealAnalysisView.swift` — `ItemSwapTarget` wrapper, swap button, sheet presentation, `applyFoodSelection`, `recomputeTotalsFromItems`, delete path now recomputes
- `Vital/Views/Today/TodayView.swift` — `.task(id:)` refactor, removed `lastLoadTime` + all call sites
- `Vital/Views/Activity/ActivityView.swift` — `.task(id:)` refactor, wired `onUpdated` alongside `onDeleted`
- `Vital/Views/Profile/ProfileView.swift` — `.task(id:)` refactor, removed `lastLoadTime`
- `Vital/Views/Workouts/WorkoutDetailView.swift` — `@State currentWorkout` via explicit init, `isEditable` gate, Edit toolbar button, edit sheet, `onUpdated` callback, new `WorkoutEditView` struct
- `project.yml` — `CURRENT_PROJECT_VERSION` 19 → 20
- `Vital.xcodeproj/project.pbxproj` — regenerated by xcodegen

### Files Modified (Web Dashboard)
- `src/lib/data.ts` — new `updateWorkout(userId, id, patch)`
- `src/app/api/workouts/route.ts` — new `PATCH` handler, imports `updateWorkout`

### Backend Deployments
- Vercel prod deploy (`dpl_BewHv3wpxTSnyDsBp9xRBv1dvkpn`) — readyState READY, target production

### Bugs Found
- **3-second debounce in `.onChange(refreshToken)` was eating the post-sync bump on cold launch.** Added in Session 10 to prevent double-fire between `.task` and the post-sync bump — fixed the symptom but introduced the race. `.task(id:)` is the right primitive for this: it fires on first appear AND on every id change, with native per-id cancellation, no manual debounce required.
- **X-delete in MealAnalysisView was cosmetic-only.** Items were displayed but never summed back into the saved totals, so deleting a wrong item left the top-level cal/protein/carbs/fat unchanged. Now every mutation (swap, delete) calls `recomputeTotalsFromItems()` so the saved totals always match the visible line items.
- **SourceKit indexer persistent false positives.** Every edit to TodayView/ActivityView/ProfileView/WorkoutDetailView/MealAnalysisView triggered the same block of "Cannot find type 'APIService' in scope" warnings even though the types are in sibling files and xcodebuild compiled cleanly. These are stale indexer artifacts that don't affect the actual build. Ignored throughout the session.

### Decisions
- **Per-item swap over whole-meal swap** (user picked via AskUserQuestion) — best when the scan gets most items right but one wrong, which is the common failure mode. Whole-meal swap can be added later if needed.
- **Manual + Quick Log editable only** (user picked via AskUserQuestion) — matches how most fitness apps work. Apple Watch/Oura/Whoop/Garmin stay read-only because their values are authoritative from the source device; edits would drift and risk being overwritten by the next sync.
- **Backend PATCH returns `{success: true}` not the updated row.** The server would have to re-fetch via `.select().single()` (which returns snake_case) and map to camelCase. Simpler: iOS already has the old object + knows which fields it changed, so it synthesizes the new Workout locally and passes it to `onUpdated`. One round trip, no mapping layer.
- **`@State currentWorkout` via explicit init over prop-as-source-of-truth.** Needed because the sheet-presented detail view has a `let workout` prop that can't be mutated. Holding local state seeded from the prop lets the edit flow update the UI in place before the parent list reload lands. Same pattern SwiftUI uses for editable details with parent-owned data.
- **`.task(id:)` over `onChange + manual debounce`.** The native primitive handles cancellation correctly and removes the bug class entirely. Any time you find yourself writing "if enough time has passed since the last run, do it again", that's a `.task(id:)` waiting to happen.
- **One bundled commit for iOS.** Three user-facing fixes but they're independent and low-risk. A split commit would add noise without reducing risk.

### Shipping
- Web dashboard commit `73dfef6` — "Workouts PATCH endpoint for editing Manual/Quick Log workouts"
- iOS commit `53c23b7` — "Session 24 — meal scan swap, refresh race fix, workout edit, build 20"
- Both repos pushed to `origin/main`
- **TestFlight build 20 uploaded** via Xcode Organizer (App upload complete dialog confirmed: "Vital 1.0.0 (20) uploaded")

### Status
- Meal scan swap: **Complete, tested on device, shipped**
- Today refresh race: **Complete, tested on device, shipped**
- Workout edit: **Complete, tested on device, shipped**
- Backend PATCH: **Deployed to Vercel prod**
- TestFlight build 20: **Uploaded, processing in App Store Connect**

### What's Next (for next session)
1. **Click Apple's "Request Access" for App Store Connect API** — 5-minute click-through, unlocks fully scriptable TestFlight uploads. Still deferred.
2. **App Store screenshots** — the real bottleneck to submission. Need 6.9" and 6.5" captures of Today, Activity, Workout detail, Nutrition, Profile, AI chat.
3. **App Store description** — app name, subtitle, keywords, description copy, promo text, support URL.
4. **Test onboarding with a fresh account** — catches anything the happy-path refactor missed.
5. **Submit to App Store** — everything else is in place.

---

## 2026-04-09/10 — Session 23

Long session. Started with a user report that "the app is running much slower now, it's taking a lot of time to load pages, and sometimes it just stays in a loading state" and ended with TestFlight build 19 uploaded carrying a massive perf overhaul, the full Session 22 encoder-bug audit finally closed out, an animated splash screen, food database integration into the meal edit flow, workout delete, and a handful of cross-cutting UX fixes.

### Refresh performance overhaul

User-reported regression: foreground return was taking ~5-10 seconds with the UI frozen and cards flashing to skeletons on every refresh.

**Root cause:** three separate `onChange(of: scenePhase)` handlers — one in MainTabView, one in TodayView, one in ActivityView — were all firing simultaneously on every foreground return. Each called `authService.refreshSession()` (so 3× concurrent Supabase auth refreshes), plus HealthKit sync, plus Oura sync, plus each tab's own API load sequence. Total cold-foreground: ~8-12 concurrent operations. On top of that, every `loadData()` set `isLoading = true` unconditionally, wiping the existing data to a skeleton before the new data arrived.

**Fix (Tier 1 + Tier 2):**
- **New `Vital/Services/RefreshCoordinator.swift`** (`@Observable`) — single source of truth. Exposes a `refreshToken: Int` that tabs observe via `.onChange`. `MainTabView` is now the *only* view listening to `scenePhase`.
- **`ContentView.swift` MainTabView** — on foreground, debounces (10s cooldown to kill rapid app-switcher toggles), calls `refreshSession()` once, runs device-appropriate sync (HealthKit OR Oura, mutually exclusive), then bumps the coordinator's `refreshToken`. Tabs observe the bump and each reloads its own data once.
- **`TodayView`, `ActivityView`, `ProfileView` `scenePhase` handlers — deleted.** All three subscribe to the coordinator instead.
- **First-load vs refresh branching in all three tabs** — `isLoading = metrics.isEmpty` (or equivalent). First load shows the skeleton; refresh keeps existing data visible and silently logs errors instead of wiping the screen.
- **`AuthService.refreshSession()`** — 60s debounce (Supabase tokens live ~1 hour, no reason to refresh on every foreground). Added `force: Bool = false` so APIService can bypass the debounce on a real 401.
- **Oura sync** — 5-minute static cooldown via `MainTabView.lastOuraSyncAt`.
- **`APIService`** — URLSession `timeoutInterval` 30s → 15s. Failing fast beats silently hanging.
- **HealthKit sync + Oura sync** — serialized on cold launch (the previous task-group plumbing hit a Swift 6 region-isolation checker bug and was unnecessary anyway, since a user is exactly one device type).

### Encoder bug audit (Session 22 carry-over, closed for real this time)

Session 22 found `apiService.post(_:body:)` silently dropping camelCase fields on the nutrition save path due to `JSONEncoder`'s `.convertToSnakeCase` colliding with backend routes that read camelCase. The session-end TODO was to audit the only other two callers: `QuickLogView` (quick log workout) and `WorkoutDetailView.AddExerciseView` (add exercise).

**Investigation:** Queried Supabase for historical evidence.
- `QuickLogView` → `/api/workouts` — sends `{type, name, duration, calories, date, notes}` but backend expects `{workoutName, durationMin, activeCalories, ...}`. **Worse**: `workout_name` is NOT NULL in the DB, so every iOS Quick Log save has been throwing a constraint violation silently. Zero manual rows since 2026-03-30 — the feature has been 100% non-functional for weeks, user just didn't notice because Apple Watch sync (193 rows) is the primary workout source.
- `WorkoutDetailView.AddExerciseView` → `/api/exercises` — sends camelCase `{workoutDate, muscleGroup, weightLbs, restSec}` which the encoder converts to snake_case on wire, but `createExerciseLogEntry` in `data.ts` reads camelCase. All four fields silently dropped. Found exactly **one signature-perfect orphan row** in `exercise_log` from 2026-03-30: `"Dumbbell Bench Press"` with NULL workout_date / muscle_group / weight_lbs / rest_sec. Lou tried it once, saw garbage, never touched the feature again.

**Fixes:**
- **`QuickLogView.swift`** — `save()` now uses `postRaw` with a raw `[String: Any]` dict keyed to the backend's actual field names. Error display uses `(error as? APIError)?.errorDescription` so real messages surface.
- **`WorkoutDetailView.swift` AddExerciseView** — same treatment. Added `errorMessage` state + UI display (the catch block was previously completely silent). Save path now dismisses the sheet after success so the parent reloads and the user sees their saved exercise.
- **Deleted trap structs**: `QuickLogBody` (inline in QuickLogView.swift), `ExerciseLogBody` (AppModels.swift), `NutritionLogBody` (AppModels.swift). Updated the dangling reference comment in `MealFormView.swift`.
- **Deleted `apiService.post(_:body:)` and `patch(_:body:)` entirely** from `APIService.swift`. Zero callers remain. Added an explanatory comment where they used to be, pointing future devs at `postRaw` / `patchRaw`. **This bug class is now impossible to reintroduce.**
- **Deleted orphan exercise_log row** (`b7a2c066-d92f-4521-b707-71975b744e10`) via Supabase MCP.
- **Backend `/api/workouts` + `/api/exercises` error handlers** — now extract `.message` from Error-shaped objects instead of `String(error)` which yielded `"[object Object]"`. Same fix we applied to `/api/nutrition` in Session 22.

### Workout type CHECK constraint found mid-audit

After the initial QuickLog fix, the user's "HIIT" test still failed with a server 500 ("[object Object]"). The deployed error handler fix surfaced the real error: `workouts_type_check` CHECK constraint requires the **exact capitalized** set `{HIIT, Strength, Cardio, Flexibility, Walking, Other}`. iOS was sending lowercase `hiit`, `strength`, etc. Plus iOS had four categories not in the DB set at all: `running`, `cycling`, `swimming`, `yoga`.

**Temporary fix:** iOS-side mapping — the picker's `dbValue` sent `Cardio` for Running/Cycling/Swimming and `Flexibility` for Yoga.

**Permanent fix:** Supabase migration `expand_workout_types` — dropped and recreated the constraint to accept the full set `{HIIT, Strength, Cardio, Running, Cycling, Swimming, Flexibility, Yoga, Walking, Other}`. Applied to prod via MCP. iOS mapping code removed; `QuickLogView.workoutTypes` now sends canonical DB values directly (id == dbValue).

### Animated splash screen

User reported: "The initial launch from the new build took an extremely long time. I also think we need a cool loading screen on initial app launch."

First-install launches are slow due to iOS signature verification + HealthKit first-auth + Supabase session provisioning + cold Vercel functions. The existing `ProgressView().tint(.white)` spinner during `authService.isLoading` made those seconds feel endless.

**New `Vital/Views/SplashView.swift`:**
- Gradient circle + "V" mark matching `LoginView` exactly (zero visual snap on handoff to auth screen)
- Breathing animation: halo (blurred) scales 0.92→1.08, gradient circle 0.96→1.04, letter 0.98→1.02 — all on a 1.8s ease-in-out repeatForever loop with parallax depth
- Ambient periwinkle radial gradient pulsing counter-phase to the mark on a 2.4s cycle
- "VITAL" wordmark with 8pt letter-spacing
- Rotating status text (LOADING → SYNCING YOUR DATA → ALMOST READY) via a structured-concurrency `Task` loop that cycles every 1.8s and auto-cancels when the view tears down
- Fades in via `appeared` state, breathing kicks off 0.3s later via `DispatchQueue.main.asyncAfter` so the initial fade-in doesn't fight the repeat-forever loop

**ContentView restructure** — single splash instance via ZStack overlay pattern. Previously I had `SplashView()` in two separate `if` branches (one for `authService.isLoading`, one for `!profileChecked`), which SwiftUI treats as two different view identities — the second instance mounted fresh when auth finished, resetting `breathe`/`appeared`/`messageIndex`. User reported "the vital thing loads twice." Fixed by:
- Body is now a `ZStack { contentLayer; if showSplash { SplashView().transition(.opacity) } }`
- `showSplash` computed: `authService.isLoading || (authService.isSignedIn && deviceType != nil && !profileChecked)`
- `.animation(.easeOut(duration: 0.35), value: showSplash)` on the ZStack
- `contentLayer` is a `@ViewBuilder` that switches between LoginView / DeviceSelectionView / `Color.clear.task { await checkProfile() }` / OnboardingView / MainTabView
- The splash now stays mounted continuously from the first frame through the auth + profile-check chain

**LoginView/DeviceSelectionView flicker fix** — user reported "right at the end of the splash the login screen tries to creep in and then it goes to the today page." Race condition: when `authService.isLoading` flipped false and `isSignedIn` flipped true in the same Supabase SDK callback, SwiftUI re-rendered the body once before the `onChange(isSignedIn)` handler had a chance to load `deviceType` from UserDefaults. That single frame had `(isSignedIn=true, deviceType=nil)` → showSplash evaluated false → contentLayer showed DeviceSelectionView. Fix: seeded `deviceType` from UserDefaults **at `@State` initialization time** so existing users never render with `deviceType == nil` during that window.

### Meal and workout UX

#### Meal edit stale-prefill bug
User reported: "when you click on an existing meal, no edit screen shows up on the first click, the fields display as empty, but if I go back and click again it shows the data filled out."

Classic `.sheet(isPresented:)` stale-closure bug. `NutritionView` had `@State var showMealForm = false` + `@State var editingMeal: NutritionEntry?` and the sheet's content closure captured `editingMeal` at build time, before it updated on the tap gesture.

**Fix:** Converted to `.sheet(item: $mealForm)` with a new `MealFormPresentation` enum (`.create | .edit(NutritionEntry)`). `.sheet(item:)` re-evaluates its content closure whenever the `id` changes, so the closure receives fresh values atomically. Same Session 22 pattern we used for `FoodSearchView.MealPrefill`.

#### Meal delete
Added `onDeleted: (() -> Void)?` callback to `MealFormView`. New "Delete Meal" destructive button visible in edit mode only, below the Save button, wired through a confirmation dialog. `NutritionView`'s edit presentation hands a delete closure that invokes the existing `deleteMeal()` function.

#### Workout delete
New backend endpoint:
- `deleteWorkout(userId, id)` in `src/lib/data.ts`
- `DELETE /api/workouts?id=xxx` handler in `route.ts`
- Deployed to Vercel prod

iOS side:
- `WorkoutDetailView` — new destructive "Delete Workout" button at the bottom of the detail view, confirmation dialog, `isDeleting` state with inline spinner
- New `onDeleted: ((String) -> Void)?` callback to the parent; `ActivityView` passes a closure that removes the row from its local `workouts` array on success (no refetch needed)
- Note in the confirm dialog: "Exercises logged on the same date are kept" — `exercise_log` has no FK to `workouts`, just a shared date

#### Food database integration into meal edit
User observation: "if someone goes to edit a logged meal, they don't get the database again. Maybe we just cook it in to everything."

Previously the food database search was only reachable from the top-level action sheets. Editing a meal meant falling back to pure manual entry.

**`FoodSearchView` selection mode:**
- New optional parameter `onFoodSelected: ((MealSelection) -> Void)? = nil`
- New `MealSelection` payload struct (food name, brand, scaled macros)
- New computed `isSelectionMode: Bool { onFoodSelected != nil }`
- When `isSelectionMode`: cart bar hidden, "Log manually instead" fallback hidden, `mealPrefill` sheet gated, `.sheet(item: $mealPrefill)` path not reachable
- New `useCurrentFoodAsSelection()` helper that builds a `MealSelection` from the current food/serving/multiplier and fires the callback + dismisses
- `selectFood` error fallback branches: in selection mode it uses the list-row data directly instead of opening a nested manual form (avoids sheet-on-sheet-on-sheet)
- Primary action button label branches: "Add to Meal" in cart mode → "Use This Food" in selection mode
- **Zero risk to the existing cart flow** — existing callers (Today/Activity/Nutrition action sheets) pass `nil` for `onFoodSelected` and get the unchanged multi-item cart experience

**`MealFormView`:**
- New prominent "Search" button (periwinkle pill with magnifying glass) just below the Meal Type chips, visible in both create and edit modes
- Also added a subtle toolbar magnifying glass for power users / nav-bar shortcut enthusiasts
- Tapping opens `FoodSearchView` in selection mode; callback populates `name` / `calories` / `protein` / `carbs` / `fat` state — meal type is preserved
- User reviews and taps Update Meal to persist

#### "Log Manually" removed from action sheets
The action sheets on Today, Activity, and Nutrition now only show Search Food Database + Scan Meal Photo. Manual entry is still reachable via FoodSearchView's "Log manually instead" fallback when a search returns no results. Deleted the dead `showMealForm` state + sheet from Today and Activity. Nutrition's empty-state "Log a Meal" button now opens the action sheet instead of jumping to a blank manual form.

#### AddExerciseView refresh fix
User report: "it just goes back to add an exercise and doesn't log the previous entry." The save was actually landing in the DB (verified via Supabase — found two fresh rows mid-session), but the form reset to empty and the user had no feedback. Changed `save()` to `dismiss()` after success instead of resetting the form. The parent's `onDismiss` handler (which already existed) reloads the exercises list, so the just-added exercise appears visually.

#### MealReviewView double-dismiss fix
User report: "after you save the meal it redirects back to the home page which is a weird move." Classic SwiftUI sheet-on-sheet dismissal bug. `MealReviewView.save()` was calling `onSaved()` (which fired `FoodSearchView.dismiss()` via the outer closure) AND `dismiss()` (which dismissed MealReviewView) in the same tick. The second dismiss fired on an already-unmounting view and SwiftUI propagated it up the sheet chain, popping the user back to the root tab. Fix: removed the extra `dismiss()` from `MealReviewView.save()`. The parent `FoodSearchView`'s dismissal cascades down to unmount `MealReviewView` as a side effect. One dismiss in the whole chain.

### Post-save navigation

User observation: "when you quick log a meal from the today page it goes back to the today page, can we make it so that whenever you log a meal/workout it goes to the page where they can see the results?"

Extended `RefreshCoordinator` with `selectedTab: Int`. `MainTabView` now binds `TabView(selection: $coordinator.selectedTab)` via `@Bindable` instead of local `@State`. Any view can programmatically switch tabs by mutating the coordinator.

`TodayView` meal save paths (both `MealAnalysisView` and `FoodSearchView`) now pass `onSaved: { refreshCoordinator.selectedTab = 1 }`, jumping the user to Activity tab after a successful save. Doesn't affect saves originating from Activity itself (already there) or from inside `NutritionView` (user stays in their drilldown).

Workouts don't have a Today-tab entry point (removed in Session 10), so there's no symmetric fix needed — they're always logged from Activity.

### Files Created
- `Vital/Services/RefreshCoordinator.swift`
- `Vital/Views/SplashView.swift`

### Files Modified (iOS)
- `Vital/VitalApp.swift` — injects RefreshCoordinator into environment
- `Vital/Services/AuthService.swift` — 60s refreshSession debounce, `force` parameter
- `Vital/Services/APIService.swift` — deleted `post(body:)` and `patch(body:)`, timeout 30s→15s, 401 retry forces refresh
- `Vital/Views/ContentView.swift` — ZStack splash overlay, contentLayer view builder, MainTabView scenePhase handler with 10s debounce, TabView bound to coordinator, deviceType seeded from UserDefaults at init
- `Vital/Views/Today/TodayView.swift` — scenePhase handler removed, coordinator observation, first-load vs refresh branching, meal save callbacks switch to Activity tab
- `Vital/Views/Activity/ActivityView.swift` — scenePhase handler removed, coordinator observation, first-load vs refresh branching, Log Manually removed, workout onDeleted wiring
- `Vital/Views/Profile/ProfileView.swift` — coordinator observation, first-load vs refresh branching, isCancelled handling
- `Vital/Views/Nutrition/NutritionView.swift` — MealFormPresentation enum, .sheet(item:) presentation, empty-state button redirect, Log Manually removed
- `Vital/Views/Nutrition/MealFormView.swift` — onDeleted callback, Delete Meal button, Search food database button (in-form + toolbar), showFoodSearch sheet with selection callback
- `Vital/Views/Nutrition/FoodSearchView.swift` — MealSelection struct, onFoodSelected callback, selection mode gating for cart/fallback/nested sheet, useCurrentFoodAsSelection helper, double-dismiss fix in MealReviewView.save
- `Vital/Views/Workouts/QuickLogView.swift` — postRaw save with correct field names, WorkoutTypeOption struct, canonical DB values (no mapping)
- `Vital/Views/Workouts/WorkoutDetailView.swift` — AddExerciseView postRaw save + dismiss after success + error display, Delete Workout button, onDeleted callback, deleteWorkout() function
- `Vital/Models/AppModels.swift` — deleted ExerciseLogBody and NutritionLogBody
- `project.yml` — declared CFBundleShortVersionString and CFBundleVersion as template variables (fixes Session 22 fragility where `xcodegen` would overwrite the literal edits), CURRENT_PROJECT_VERSION 18 → 19

### Files Modified (Web Dashboard)
- `src/app/api/workouts/route.ts` — new DELETE handler, `.message` extraction in error paths
- `src/app/api/exercises/route.ts` — `.message` extraction in error paths
- `src/lib/data.ts` — new `deleteWorkout()` function

### Database Migrations
- `expand_workout_types` — `workouts_type_check` now accepts Running/Cycling/Swimming/Yoga in addition to the original set

### Backend Deployments
- Error handler fixes + workouts DELETE endpoint force-deployed to Vercel prod

### Bugs Found
- **`apiService.post(_:body:)` encoder snake_case bug existed in two more views** (QuickLogView, WorkoutDetailView) beyond the nutrition path found in Session 22. Both are now fixed AND the method is deleted so the bug class is extinct.
- **`workouts_type_check` CHECK constraint** required exact capitalized values including a fixed set that didn't cover iOS's picker categories. Solved via DB migration rather than iOS-side mapping.
- **Sheet-on-sheet double dismissal cascades past the inner sheet's parent.** In SwiftUI, calling `dismiss()` twice in rapid succession across two sheets propagates the second call up the chain and dismisses *grandparent* views. The fix is: whoever presents the inner sheet owns the dismiss, never both.
- **Two separate `SplashView()` instances in an if/else-if chain are NOT identity-equal in SwiftUI.** Even when both render the same view type, SwiftUI treats the two branches as structurally different positions and mounts a fresh instance when moving between them. Fix: single instance at the same position (e.g. in a ZStack overlay) with conditional visibility via a computed property.
- **`deviceType: DeviceType?` as `@State private var deviceType: DeviceType?` has a race window on cold launch** where `isSignedIn` flips true before `onChange` can populate deviceType from UserDefaults. Fix: seed at `@State` init time with a closure that reads UserDefaults synchronously.
- **Swift 6 region-based isolation checker bug with `TaskGroup.addTask { @MainActor in ... }`** — produced "pattern that the region-based isolation checker does not understand how to check. Please file a bug" errors. Workaround: don't use TaskGroup for cases where you can use simple conditional awaits.
- **"[object Object]" masking real backend errors** on `/api/workouts` and `/api/exercises` because `String(error)` on Supabase PostgrestError stringifies to that. Same fix as Session 22's `/api/nutrition`.

### Decisions
- **Delete `apiService.post(_:body:)` entirely** rather than keep it with a warning comment. Warning comments get ignored; deleting the method makes the bug impossible to write. `postStream` remains but only encodes `ChatRequest` (single-word fields, immune).
- **Selection mode in FoodSearchView over a new dedicated view** — reusing the existing search/serving-picker UI is much less code than building a parallel version for edit, and the gating logic is straightforward (`isSelectionMode` computed property).
- **Expand the DB constraint instead of mapping on iOS** for workout types. Schema migration is trivial, zero existing data affected, and preserves category fidelity for every future save. iOS-side mapping would have meant Running/Cycling/Swimming rows all showing up as "Cardio" in history.
- **Keep the toolbar magnifying glass in addition to the prominent in-form "Search" button.** Redundant but discoverable via two different patterns (primary action in form, secondary shortcut in nav bar).
- **`MealFormView` Delete button in edit mode only, below Save, destructive-styled** — matches the Session 22 meal form aesthetic, confirmation dialog prevents fat-finger deletes.
- **Tab switching only from Today → Activity after meal save.** Not from Activity → Activity (no-op), not from edit flows (user already knows where the data is), not from workouts (no Today entry point). Scoped change, doesn't touch unrelated flows.
- **One big Session 23 iOS commit + one web commit + one version-bump commit** rather than splitting by feature. The features are intertwined (meal edit touches FoodSearchView which touches tab switching which touches RefreshCoordinator), and a more granular split would require more cross-commit fixup.

### Shipping
- **Both repos pushed to GitHub** (vital-companion-app + vital-health-dashboard)
- **TestFlight build 19 uploaded** via Xcode Organizer — processing in App Store Connect
- CURRENT_PROJECT_VERSION bumped to 19, Info.plist templates propagated cleanly (Session 22 project.yml fix held up)

### Status
- Refresh perf overhaul: **Shipped**
- Encoder bug audit: **Closed for real this time** — bug class is extinct
- Animated splash screen: **Shipped**
- Meal edit + food database integration: **Shipped**
- Meal delete + workout delete: **Shipped**
- Workout type expansion: **Migrated + deployed**
- Post-save tab switching: **Shipped**
- TestFlight build 19: **Uploaded**

### What's Next (for next session)
1. **Click Apple's "Request Access" for App Store Connect API** — 5-minute click-through, unlocks fully scriptable TestFlight uploads. Still deferred.
2. **Test build 19 on device** once App Store Connect finishes processing
3. **App Store screenshots + description**
4. **Test onboarding with a fresh account**
5. **Submit to App Store**

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
