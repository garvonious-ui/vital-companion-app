import SwiftUI

struct WorkoutDetailView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    let workout: Workout

    @State private var exercises: [ExerciseLogEntry] = []
    @State private var isLoadingExercises = true
    @State private var showAddExercise = false

    private var workoutDate: String {
        String(workout.date.prefix(10))
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
                        if let muscles = workout.muscleGroups, !muscles.isEmpty {
                            muscleGroupPills(muscles)
                        }

                        // Exercise log
                        exerciseSection

                        // Notes
                        if let notes = workout.notes, !notes.isEmpty {
                            notesCard(notes)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(workout.name ?? (workout.type ?? "Workout").capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .task {
                await loadExercises()
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name ?? (workout.type ?? "Workout").capitalized)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text(formatDate(workout.date))
                    .font(.subheadline)
                    .foregroundColor(Brand.textMuted)
            }

            Spacer()

            Text((workout.type ?? "Other").capitalized)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(workoutTypeColor(workout.type ?? "Other").opacity(0.15))
                .foregroundColor(workoutTypeColor(workout.type ?? "Other"))
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
            if let duration = workout.duration {
                statItem(value: "\(duration)", unit: "min", icon: "clock")
            }
            if let cals = workout.calories {
                statItem(value: "\(cals)", unit: "kcal", icon: "flame.fill")
            }
            if let avgHR = workout.avgHeartRate {
                statItem(value: "\(avgHR)", unit: "avg bpm", icon: "heart.fill")
            }
            if let maxHR = workout.maxHeartRate {
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
        }
        .padding(10)
        .background(Brand.elevated)
        .cornerRadius(10)
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
            let resp: APIResponse<[ExerciseLogEntry]> = try await apiService.get("/exercises?date=\(workoutDate)")
            exercises = resp.data ?? []
        } catch {
            // Non-critical
        }
        isLoadingExercises = false
    }
}

// MARK: - Add Exercise View

struct AddExerciseView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    let workoutDate: String

    @State private var library: [LibraryExercise] = []
    @State private var searchText = ""
    @State private var exerciseName = ""
    @State private var muscleGroup = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var isSaving = false

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

                        // Save
                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Add Exercise")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(Brand.textPrimary)
                            .background(exerciseName.isEmpty ? Brand.textMuted : Brand.accent)
                            .cornerRadius(12)
                        }
                        .disabled(exerciseName.isEmpty || isSaving)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.accent)
                }
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
        let body = ExerciseLogBody(
            exercise: exerciseName,
            workoutDate: workoutDate,
            muscleGroup: muscleGroup.isEmpty ? nil : muscleGroup,
            sets: Int(sets),
            reps: reps.isEmpty ? nil : reps,
            weightLbs: Double(weight),
            restSec: nil,
            notes: nil
        )

        do {
            let _: APIResponse<String?> = try await apiService.post("/exercises", body: body)
            HapticManager.success()
            // Reset for adding another
            exerciseName = ""
            searchText = ""
            muscleGroup = ""
            sets = ""
            reps = ""
            weight = ""
            isSaving = false
        } catch {
            isSaving = false
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
