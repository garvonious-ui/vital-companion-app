import SwiftUI

struct WorkoutDetailView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    /// Held as `@State` so the edit flow can mutate it in place after a
    /// successful PATCH — the user sees the updated values immediately
    /// without waiting for a parent reload. Seeded from the prop at init.
    @State private var currentWorkout: Workout

    /// Optional callback fired after a successful delete (before dismiss).
    /// Parent views use this to remove the workout from their list without
    /// a full reload.
    var onDeleted: ((String) -> Void)? = nil
    /// Optional callback fired after a successful edit. Parent views use
    /// this to replace the row in their local list.
    var onUpdated: ((Workout) -> Void)? = nil

    init(workout: Workout, onDeleted: ((String) -> Void)? = nil, onUpdated: ((Workout) -> Void)? = nil) {
        _currentWorkout = State(initialValue: workout)
        self.onDeleted = onDeleted
        self.onUpdated = onUpdated
    }

    @State private var exercises: [ExerciseLogEntry] = []
    @State private var isLoadingExercises = true
    @State private var showAddExercise = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    /// When non-nil, presents the exercise edit sheet. Uses `.sheet(item:)`
    /// so the closure captures the specific entry atomically (Session 22
    /// stale-prefill pattern).
    @State private var editingExercise: ExerciseLogEntry? = nil

    /// Only Manual / Quick Log workouts are editable. Apple Watch, Oura,
    /// Whoop, Garmin workouts stay read-only because their values are
    /// authoritative from the source device — user edits would drift away
    /// from the source of truth and risk being overwritten by the next sync.
    private var isEditable: Bool {
        guard let source = currentWorkout.source else { return false }
        return source == "Manual" || source == "Quick Log"
    }

    private var workoutDate: String {
        String(currentWorkout.date.prefix(10))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header + type badge
                        headerCard

                        // Stats row
                        statsRow

                        // Muscle groups
                        if let muscles = currentWorkout.muscleGroups, !muscles.isEmpty {
                            muscleGroupPills(muscles)
                        }

                        // Exercise log
                        exerciseSection

                        // Notes
                        if let notes = currentWorkout.notes, !notes.isEmpty {
                            notesCard(notes)
                        }

                        // Delete workout button — destructive, at the bottom
                        // so the user has to scroll past the content to reach
                        // it. Confirmation dialog prevents accidental taps.
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                if isDeleting {
                                    ProgressView().tint(Brand.critical).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "trash")
                                }
                                Text("Delete Workout")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(Brand.critical)
                        }
                        .disabled(isDeleting)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(currentWorkout.name ?? (currentWorkout.type ?? "Workout").capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditable {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") { showEditSheet = true }
                            .foregroundColor(Brand.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Brand.accent)
                }
            }
            .sheet(isPresented: $showAddExercise, onDismiss: {
                Task { await loadExercises() }
            }) {
                AddExerciseView(workoutDate: workoutDate)
            }
            .sheet(item: $editingExercise) { entry in
                AddExerciseView(
                    workoutDate: workoutDate,
                    existingEntry: entry,
                    onSaved: {
                        // Reload so the row reflects the new values.
                        // Using loadExercises() rather than in-place mutation
                        // because the PATCH body can change name + muscle
                        // group, and we don't echo those back from the server.
                        Task { await loadExercises() }
                    },
                    onDeleted: {
                        // Remove locally so the row disappears immediately.
                        // Parent's exercises array is the source of truth for
                        // the list; no fetch needed.
                        exercises.removeAll { $0.id == entry.id }
                    }
                )
            }
            .sheet(isPresented: $showEditSheet) {
                WorkoutEditView(workout: currentWorkout) { updated in
                    // Mutate local state so the detail view re-renders in
                    // place with the new values immediately. Then notify
                    // the parent so the list row updates too.
                    currentWorkout = updated
                    onUpdated?(updated)
                }
            }
            .confirmationDialog(
                "Delete this workout?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await deleteWorkout() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone. Exercises logged on the same date are kept.")
            }
            .task {
                await loadExercises()
            }
        }
    }

    // MARK: - Delete

    private func deleteWorkout() async {
        isDeleting = true
        do {
            let _: SuccessResponse = try await apiService.delete(
                "/workouts",
                queryItems: [URLQueryItem(name: "id", value: currentWorkout.id)]
            )
            HapticManager.success()
            onDeleted?(currentWorkout.id)
            dismiss()
        } catch {
            HapticManager.error()
            isDeleting = false
            // No error UI here — we could add one, but the delete either
            // succeeds or the user retries. Keeping surface area small.
            print("[WorkoutDetailView] delete failed: \(error)")
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentWorkout.name ?? (currentWorkout.type ?? "Workout").capitalized)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text(formatDate(currentWorkout.date))
                    .font(.subheadline)
                    .foregroundColor(Brand.textMuted)
            }

            Spacer()

            Text((currentWorkout.type ?? "Other").capitalized)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(workoutTypeColor(currentWorkout.type ?? "Other").opacity(0.15))
                .foregroundColor(workoutTypeColor(currentWorkout.type ?? "Other"))
                .cornerRadius(6)
        }
        .padding(16)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            if let duration = currentWorkout.duration {
                statItem(value: "\(duration)", unit: "min", icon: "clock")
            }
            if let cals = currentWorkout.calories {
                statItem(value: "\(cals)", unit: "kcal", icon: "flame.fill")
            }
            if let avgHR = currentWorkout.avgHeartRate {
                statItem(value: "\(avgHR)", unit: "avg bpm", icon: "heart.fill")
            }
            if let maxHR = currentWorkout.maxHeartRate {
                statItem(value: "\(maxHR)", unit: "max bpm", icon: "heart.fill")
            }
        }
        .padding(16)
        .background(Brand.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func statItem(value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Brand.accent)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(Brand.textPrimary)
            Text(unit)
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Muscle Groups

    private func muscleGroupPills(_ muscles: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(muscles, id: \.self) { muscle in
                    Text(muscle)
                        .font(.caption.weight(.medium))
                        .foregroundColor(Brand.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Brand.secondary.opacity(0.12))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
                Button {
                    showAddExercise = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2)
                        Text("Add")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(Brand.accent)
                }
            }

            if isLoadingExercises {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.title2)
                        .foregroundColor(Brand.textMuted)
                    Text("No exercises logged")
                        .font(.subheadline)
                        .foregroundColor(Brand.textMuted)
                    Button {
                        showAddExercise = true
                    } label: {
                        Text("Add what you did")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Brand.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Brand.accent.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(exercises) { exercise in
                    exerciseRow(exercise)
                }
            }
        }
        .padding(16)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func exerciseRow(_ entry: ExerciseLogEntry) -> some View {
        // Tappable — opens the dual-mode AddExerciseView in edit mode via
        // the `.sheet(item: $editingExercise)` handler. Edit + delete both
        // live inside that sheet (matches MealFormView pattern).
        Button {
            HapticManager.light()
            editingExercise = entry
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.exercise)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Brand.textPrimary)

                    HStack(spacing: 8) {
                        if let sets = entry.sets {
                            Text("\(sets) sets")
                        }
                        if let reps = entry.reps, !reps.isEmpty {
                            Text("× \(reps)")
                        }
                        if let weight = entry.weightLbs, weight > 0 {
                            Text("@ \(Int(weight)) lbs")
                        }
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Brand.textSecondary)
                }

                Spacer()

                if let muscle = entry.muscleGroup, !muscle.isEmpty {
                    Text(muscle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Brand.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Brand.secondary.opacity(0.12))
                        .cornerRadius(4)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Brand.textMuted)
            }
            .padding(10)
            .background(Brand.elevated)
            .cornerRadius(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Brand.textSecondary)
            Text(notes)
                .font(.subheadline)
                .foregroundColor(Brand.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func workoutTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "strength": return Brand.secondary
        case "cardio", "running": return Brand.optimal
        case "hiit": return Brand.critical
        case "flexibility", "yoga": return Brand.accent
        default: return Brand.warning
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        guard let date = df.date(from: String(dateStr.prefix(10))) else { return dateStr }
        let out = DateFormatter()
        out.dateFormat = "EEEE, MMM d"
        return out.string(from: date)
    }

    private func loadExercises() async {
        do {
            // IMPORTANT: pass the date via queryItems, NOT by embedding `?date=`
            // in the path string. `URL.appendingPathComponent` (used inside
            // APIService.buildRequest) percent-encodes `?` to `%3F`, producing
            // a malformed URL like `/api/exercises%3Fdate=2026-04-14` which
            // Next.js 404s. This bug silently swallowed every GET since the
            // feature shipped — saves worked, but rows never showed up in the
            // detail view. Session 27 root cause.
            let resp: APIResponse<[ExerciseLogEntry]> = try await apiService.get(
                "/exercises",
                queryItems: [URLQueryItem(name: "date", value: workoutDate)]
            )
            exercises = resp.data ?? []
        } catch {
            // Log rather than swallow silently — silent catches are how the
            // Session 27 URL bug hid for this long.
            print("[WorkoutDetailView] loadExercises failed: \(error)")
        }
        isLoadingExercises = false
    }
}

// MARK: - Add/Edit Exercise View
// Despite the name, this view handles BOTH creation (existingEntry == nil) and
// editing (existingEntry != nil) of a single exercise log row. Same pattern
// MealFormView uses — one form, two modes, initialized from an optional entry.

struct AddExerciseView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    let workoutDate: String
    /// When non-nil, the view runs in EDIT mode — fields are prefilled,
    /// save calls PATCH instead of POST, and a Delete button is shown.
    let existingEntry: ExerciseLogEntry?
    /// Fired after a successful save (add or edit). Parents use this to
    /// update the exercises array in place without a full reload.
    var onSaved: (() -> Void)? = nil
    /// Fired after a successful delete. Only relevant in edit mode.
    var onDeleted: (() -> Void)? = nil

    @State private var library: [LibraryExercise] = []
    @State private var searchText = ""
    @State private var exerciseName = ""
    @State private var muscleGroup = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    init(
        workoutDate: String,
        existingEntry: ExerciseLogEntry? = nil,
        onSaved: (() -> Void)? = nil,
        onDeleted: (() -> Void)? = nil
    ) {
        self.workoutDate = workoutDate
        self.existingEntry = existingEntry
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _searchText = State(initialValue: existingEntry?.exercise ?? "")
        _exerciseName = State(initialValue: existingEntry?.exercise ?? "")
        _muscleGroup = State(initialValue: existingEntry?.muscleGroup ?? "")
        _sets = State(initialValue: existingEntry?.sets.map { "\($0)" } ?? "")
        _reps = State(initialValue: existingEntry?.reps ?? "")
        _weight = State(initialValue: existingEntry?.weightLbs.map { "\(Int($0))" } ?? "")
    }

    private var isEditing: Bool { existingEntry != nil }

    private var filteredLibrary: [LibraryExercise] {
        if searchText.isEmpty { return library }
        return library.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.primaryMuscle ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Search / select from library
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EXERCISE")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Brand.textMuted)

                            TextField("Search or type exercise name", text: $searchText)
                                .textFieldStyle(DarkFieldStyle())
                                .onChange(of: searchText) { _, newVal in
                                    exerciseName = newVal
                                }

                            // Library suggestions
                            if !searchText.isEmpty && !filteredLibrary.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(filteredLibrary.prefix(5)) { ex in
                                        Button {
                                            exerciseName = ex.name
                                            searchText = ex.name
                                            muscleGroup = ex.primaryMuscle ?? ""
                                        } label: {
                                            HStack {
                                                Text(ex.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(Brand.textPrimary)
                                                Spacer()
                                                if let muscle = ex.primaryMuscle {
                                                    Text(muscle)
                                                        .font(.caption)
                                                        .foregroundColor(Brand.textMuted)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }
                                        Divider().background(Color.white.opacity(0.04))
                                    }
                                }
                                .background(Brand.elevated)
                                .cornerRadius(10)
                            }
                        }

                        // Details
                        HStack(spacing: 12) {
                            fieldColumn(label: "Sets", text: $sets, placeholder: "4")
                            fieldColumn(label: "Reps", text: $reps, placeholder: "8-10")
                            fieldColumn(label: "Weight (lbs)", text: $weight, placeholder: "135")
                        }

                        if muscleGroup.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("MUSCLE GROUP")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Brand.textMuted)
                                TextField("e.g. Chest, Back, Legs", text: $muscleGroup)
                                    .textFieldStyle(DarkFieldStyle())
                            }
                        } else {
                            HStack {
                                Text("Muscle Group:")
                                    .font(.caption)
                                    .foregroundColor(Brand.textMuted)
                                Text(muscleGroup)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(Brand.secondary)
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Brand.critical)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Save
                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isEditing ? "Save Changes" : "Add Exercise")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(Brand.textPrimary)
                            .background(exerciseName.isEmpty ? Brand.textMuted : Brand.accent)
                            .cornerRadius(12)
                        }
                        .disabled(exerciseName.isEmpty || isSaving || isDeleting)

                        // Delete — only in edit mode. Destructive, at the
                        // bottom so it's deliberately out of the default
                        // tap path. Confirmation dialog prevents fat-fingers.
                        if isEditing {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 6) {
                                    if isDeleting {
                                        ProgressView().tint(Brand.critical).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                    Text("Delete Exercise")
                                }
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(Brand.critical)
                            }
                            .disabled(isSaving || isDeleting)
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                }
                .dismissKeyboardOnDrag()
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardToolbarDone()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.accent)
                        .disabled(isSaving || isDeleting)
                }
            }
            .confirmationDialog(
                "Delete this exercise?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await deleteExercise() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
            .task {
                await loadLibrary()
            }
        }
    }

    private func fieldColumn(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Brand.textMuted)
            TextField(placeholder, text: text)
                .textFieldStyle(DarkFieldStyle())
                .keyboardType(.numberPad)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        // Raw-dict bodies for both POST and PATCH — APIService's typed
        // `post(body:)` would convert keys to snake_case via
        // `.convertToSnakeCase`, and data.ts reads camelCase. Use postRaw/
        // patchRaw with a literal dict to bypass the encoder entirely.
        if let existing = existingEntry {
            // EDIT — PATCH /exercises with id in body
            var body: [String: Any] = ["id": existing.id]
            body["exercise"] = exerciseName
            body["muscleGroup"] = muscleGroup // empty string is fine — backend uses !== undefined
            if let s = Int(sets) { body["sets"] = s }
            body["reps"] = reps
            if let w = Double(weight) { body["weightLbs"] = w }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                let _: SuccessResponse = try await apiService.patchRaw("/exercises", jsonData: jsonData)
                HapticManager.success()
                isSaving = false
                onSaved?()
                dismiss()
            } catch {
                HapticManager.error()
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
                isSaving = false
            }
        } else {
            // ADD — POST /exercises
            var body: [String: Any] = [
                "exercise": exerciseName,
                "workoutDate": workoutDate,
            ]
            if !muscleGroup.isEmpty { body["muscleGroup"] = muscleGroup }
            if let s = Int(sets) { body["sets"] = s }
            if !reps.isEmpty { body["reps"] = reps }
            if let w = Double(weight) { body["weightLbs"] = w }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                let _: SuccessResponse = try await apiService.postRaw("/exercises", jsonData: jsonData)
                HapticManager.success()
                isSaving = false
                onSaved?()
                dismiss()
            } catch {
                HapticManager.error()
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
                isSaving = false
            }
        }
    }

    private func deleteExercise() async {
        guard let existing = existingEntry else { return }
        isDeleting = true
        errorMessage = nil
        do {
            let _: SuccessResponse = try await apiService.delete(
                "/exercises",
                queryItems: [URLQueryItem(name: "id", value: existing.id)]
            )
            HapticManager.success()
            isDeleting = false
            onDeleted?()
            dismiss()
        } catch {
            HapticManager.error()
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            isDeleting = false
        }
    }

    private func loadLibrary() async {
        do {
            let resp: APIResponse<[LibraryExercise]> = try await apiService.get("/library")
            library = resp.data ?? []
        } catch {
            // Non-critical
        }
    }
}

// MARK: - Edit Workout View

/// Edit form for Manual / Quick Log workouts. Mirrors QuickLogView's field
/// layout so the edit experience feels like editing the same form the user
/// filled in. On save, sends a PATCH to `/workouts?id=...` with the updated
/// fields, constructs a new `Workout` locally from the old one + the patch,
/// and passes it to `onSaved`. Date and source are intentionally immutable;
/// heart rate and muscle groups are out of scope for this edit surface.
struct WorkoutEditView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    let workout: Workout
    let onSaved: (Workout) -> Void

    @State private var type: String
    @State private var name: String
    @State private var duration: String
    @State private var calories: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// Same canonical set as QuickLogView — matches the expanded
    /// `workouts_type_check` constraint from the Session 23 migration
    /// `expand_workout_types`.
    private struct WorkoutTypeOption: Identifiable {
        let id: String
        let icon: String
    }

    private let workoutTypes: [WorkoutTypeOption] = [
        .init(id: "Strength", icon: "dumbbell.fill"),
        .init(id: "Running", icon: "figure.run"),
        .init(id: "Cycling", icon: "bicycle"),
        .init(id: "Swimming", icon: "figure.pool.swim"),
        .init(id: "HIIT", icon: "bolt.heart.fill"),
        .init(id: "Yoga", icon: "figure.yoga"),
        .init(id: "Walking", icon: "figure.walk"),
        .init(id: "Other", icon: "figure.mixed.cardio"),
    ]

    init(workout: Workout, onSaved: @escaping (Workout) -> Void) {
        self.workout = workout
        self.onSaved = onSaved
        _type = State(initialValue: workout.type ?? "Other")
        _name = State(initialValue: workout.workoutName ?? "")
        _duration = State(initialValue: workout.durationMin.map { "\($0)" } ?? "")
        _calories = State(initialValue: workout.activeCalories.map { "\($0)" } ?? "")
        _notes = State(initialValue: workout.notes ?? "")
    }

    private var isValid: Bool {
        !duration.isEmpty && Int(duration) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Type grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Brand.textSecondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(workoutTypes) { option in
                                    typeButton(option)
                                }
                            }
                        }

                        // Name
                        fieldGroup("Name") {
                            TextField("e.g. Push Day", text: $name)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        // Duration + Calories
                        HStack(spacing: 12) {
                            fieldGroup("Duration (min)") {
                                TextField("45", text: $duration)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(DarkFieldStyle())
                            }

                            fieldGroup("Calories") {
                                TextField("0", text: $calories)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(DarkFieldStyle())
                            }
                        }

                        // Notes
                        fieldGroup("Notes") {
                            TextField("How did it feel?", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Brand.critical)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Save
                        Button {
                            Task { await save() }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Save Changes")
                                }
                            }
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? Brand.accent : Brand.elevated)
                            .foregroundColor(isValid ? .white : Brand.textMuted)
                            .cornerRadius(12)
                        }
                        .disabled(!isValid || isSaving)

                        Spacer()
                    }
                    .padding(20)
                }
                .dismissKeyboardOnDrag()
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardToolbarDone()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.textSecondary)
                }
            }
        }
    }

    private func typeButton(_ option: WorkoutTypeOption) -> some View {
        let isSelected = type == option.id
        return Button {
            type = option.id
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.body)
                Text(option.id)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Brand.accent.opacity(0.2) : Brand.elevated)
            .foregroundColor(isSelected ? Brand.accent : Brand.textSecondary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Brand.accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(Brand.textSecondary)
            content()
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        // Raw-dict body keyed to backend camelCase field names, matching the
        // Session 23 encoder-safe pattern. `apiService.patchRaw` goes straight
        // to the wire with no snake_case conversion.
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        var body: [String: Any] = [
            "workoutName": trimmedName.isEmpty ? type : trimmedName,
            "type": type,
            "notes": notes.trimmingCharacters(in: .whitespaces),
        ]
        if let d = Int(duration) { body["durationMin"] = d }
        if let c = Int(calories) { body["activeCalories"] = c }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let _: SuccessResponse = try await apiService.patchRaw(
                "/workouts",
                jsonData: jsonData,
                queryItems: [URLQueryItem(name: "id", value: workout.id)]
            )
            HapticManager.success()
            // Construct the updated Workout locally from the old one + the
            // patch fields. The server doesn't return the updated row
            // (returning Supabase's snake_case rows would require another
            // mapping layer). Same fields that we PATCHed, same types.
            let updated = Workout(
                id: workout.id,
                workoutName: trimmedName.isEmpty ? type : trimmedName,
                date: workout.date,
                type: type,
                durationMin: Int(duration),
                activeCalories: Int(calories),
                avgHeartRate: workout.avgHeartRate,
                maxHeartRate: workout.maxHeartRate,
                muscleGroups: workout.muscleGroups,
                source: workout.source,
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            isSaving = false
            onSaved(updated)
            dismiss()
        } catch {
            HapticManager.error()
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            isSaving = false
        }
    }
}
