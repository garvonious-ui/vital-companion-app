# iOS V2 UX Redesign — Simplified 3-Tab Structure

## Why This Redesign

The current 4-tab layout (Dashboard, Workouts, Nutrition, More) is built for power users. When a non-technical person opens the app, they see a cockpit — 4 tabs, each with multiple features, and no clear answer to "how am I doing today?" This redesign simplifies the app to 3 tabs with progressive disclosure: simple on the surface, powerful underneath.

## The Goal

A user opens Vital, sees one number and one sentence about their health, and closes the app in 10 seconds feeling informed. Everything else is one tap deeper.

## Design Principle: Simple Surface, Deep Data

The top layer of every screen should be scannable in 5 seconds. But every metric, every workout, every card should be tappable into a detail view with as much data as we have. Cater to both ends: dad who glances at the recovery ring and closes the app, AND the power user who wants to drill into SpO2 trends and exercise-level workout data. Progressive disclosure is the rule everywhere.

## New Tab Structure: 3 Tabs

### Tab 1 — "Today" (replaces Dashboard)

This is the "open and get your answer" screen. One scroll, no cognitive load.

**Layout (top to bottom):**

1. **Header row** — "Good morning, [name]" with date subtitle. No settings gear, no icons competing for attention.

2. **Recovery card** — Full-width card, centered content:
   - Recovery ring (keep existing RecoveryRing component, spring animation)
   - Large recovery score number inside ring (e.g., "78")
   - "RECOVERY" label below score with ⓘ info button
   - ⓘ opens a sheet explaining: what recovery score measures, what ranges mean (80-100 strong, 60-79 solid, 40-59 moderate, below 40 rest day), data sources
   - **One-sentence AI verdict below the ring** — plain-English sentence from today's data
   - Verdict generation: local string templates (NOT AI API call), uses sleep hours, HRV vs 7-day avg, resting HR vs 7-day avg, recovery score

3. **Key metrics grid** — 2x2 grid of tappable cards:
   - Sleep: hours + quality indicator → SleepDetailView
   - Resting HR: bpm → HeartDetailView
   - Steps: count + "of [target]" subtitle → ActivityDetailView
   - HRV: ms + delta vs average → HRVDetailView
   - Each card navigates to a detail view with 7/30-day trend chart + related metrics

4. **Active calories progress bar** — single horizontal bar with "127 / 485" label. Tappable → ActivityDetailView.

5. **Quick action row** — 3 equal buttons:
   - "Log meal" → opens MealFormView
   - "Water" → quick-add water (8oz, 16oz, custom)
   - "Workout" → opens QuickLogView

6. **"Ask Vital" button** — purple gradient button, full width. Opens ChatView in sheet.

### Metric Detail Views

Each metric card taps into a MetricDetailView showing:
- 7-day trend chart (full-width, larger than sparkline)
- 30-day trend chart (toggleable)
- Today's value vs 7-day avg vs 30-day avg
- Related metrics list

**Metric detail groupings:**
- **Sleep → SleepDetailView:** sleep hours (chart), respiratory rate, SpO2, resting HR
- **Resting HR → HeartDetailView:** resting HR (chart), HRV, VO2 Max, SpO2
- **Steps → ActivityDetailView:** steps (chart), distance miles, active calories, exercise minutes
- **HRV → HRVDetailView:** HRV (chart), resting HR, sleep hours, recovery score trend
- **Active calories → ActivityDetailView:** same as steps detail

### Tab 2 — "Activity" (replaces Workouts + Nutrition)

Everything about "things I did today" and "things I'm going to do."

**Layout (top to bottom):**

1. **Today's nutrition summary card** — compact card:
   - Two numbers: Calories (current / target) and Protein (current / target)
   - Two thin progress bars (calories = white, protein = blue)
   - "+ Log meal" button
   - Tapping card opens full NutritionView (date nav, macro breakdown, meal list)

2. **Active plan card** — if user has an active workout plan:
   - Plan name, today's scheduled workout (or "Rest day")
   - "Start workout" button if training day
   - Tappable → full weekly schedule (read-only)
   - If no active plan: "Quick log" + "Create plan on web dashboard →" link

3. **Recent workouts list** — last 5 workouts:
   - Workout icon, name, date + duration + calories
   - Tappable → full WorkoutDetailView (duration, cals, HR, muscle groups, exercise log)
   - "See all" link → full workout history

4. **Quick log workout button**

### Tab 3 — "Profile" (replaces More)

Everything about "who I am" and "my health records."

**Layout (top to bottom):**

1. **Profile header** — avatar circle (initials), name, age + height + weight

2. **"Ask Vital about your health" button** — purple gradient (same as Tab 1)

3. **Health records section:**
   - Lab results — biomarker count + draw date + flag count. Taps → LabsView with category filter pills and upload button
   - Supplements — active count. Taps → SupplementsView with full CRUD (add/edit/delete)
   - Health profile — conditions, meds, goals (inline display)

4. **Trends section:**
   - Weight: current + 30-day delta
   - HRV trend: 7-day avg + direction
   - Resting HR: 7-day avg + direction
   - Tappable → trend chart views

5. **Settings section:**
   - Connected devices (deep-link to web dashboard)
   - Daily targets (edit)
   - Account (email, sign out)

## Supplements — Full CRUD

1. **Add** — "+" button, form sheet (name, type, dosage, frequency, timing, status, reason, notes) → POST /api/supplements
2. **Edit** — tap row → pre-filled form → PATCH /api/supplements
3. **Delete** — swipe-to-delete with confirmation → DELETE /api/supplements
4. Sort: Prescription first, then Supplement, then OTC

## WorkoutDetailView — Full Data

1. Header: name, date, type badge
2. Summary stats: duration, active calories, avg HR, max HR
3. Muscle groups as colored pills
4. Exercise log (from exercise_log table): exercise name, sets × reps @ weight
5. "Add exercises" if none logged → exercise library search → create entries
6. API: GET /api/exercises?workout_date=YYYY-MM-DD, POST /api/exercises, GET /api/exercise-library?q=bench

## Lab Results — Updates

1. Upload button at top (UIDocumentPickerViewController → /api/labs/parse)
2. Category filter pills (horizontal scroll): All | Flagged | Lipids | Metabolic | CBC | etc.
3. Group by status: Flagged expanded, Borderline with range bar, Optimal collapsed

## Workout Plans — Simplified

- Active plan: show on Activity tab, tappable to full schedule, "Start workout" button
- No plan: "Quick log" + "Create plan on web →" link
- No AI plan generator on iOS (stays on web)

## Brand Bible Color Pass

Do not start until brand bible is provided. Build with current dark theme first, then do a color pass at the end.

## Build Order

1. ~~Restructure tabs~~ ✅ (Session 4)
2. ~~Build TodayView~~ ✅ (Session 4)
3. **MetricDetailView** — reusable detail view (7/30-day chart, today vs avg, related metrics). Wire up all metric cards + recovery ⓘ explainer.
4. ~~Build ActivityView~~ ✅ (Session 4)
5. **WorkoutDetailView upgrade** — full workout data + exercise log + "add exercises" flow
6. **ProfileView** — replace MoreView with new layout
7. **Supplements CRUD** — add/edit/delete forms
8. **Labs updates** — upload + category filters + group-by-status
9. **Water quick-add** — sheet UI + API call
10. **Polish** — verify animations, haptics, skeletons
11. **Brand bible color pass** — apply after bible is provided
12. **Update docs** — changelog, build plan

## What NOT to Change

- Web dashboard stays as-is
- Supabase backend stays untouched
- Auth flow stays the same
- HealthKit sync stays the same
- Dark theme / color palette stays the same (until brand bible)
