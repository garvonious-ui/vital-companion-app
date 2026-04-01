import SwiftUI

struct WorkoutSessionView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    let plan: WorkoutPlan
    let day: PlanDay

    @State private var exerciseData: [ExerciseSessionData] = []
    @State private var currentExerciseIndex = 0
    @State private var showRestTimer = false
    @State private var restSeconds = 90
    @State private var restRemaining = 0
    @State private var restTimer: Timer?
    @State private var elapsedSeconds = 0
    @State private var sessionTimer: Timer?
    @State private var isSaving = false
    @State private var showFinishConfirm = false

    private var currentExercise: ExerciseSessionData? {
        guard currentExerciseIndex < exerciseData.count else { return nil }
        return exerciseData[currentExerciseIndex]
    }

    private var completedSets: Int {
        exerciseData.reduce(0) { total, ex in
            total + ex.sets.filter { $0.completed }.count
        }
    }

    private var totalSets: Int {
        exerciseData.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Session header
                    sessionHeader

                    // Exercise content
                    if let exercise = currentExercise {
                        ScrollView {
                            VStack(spacing: 16) {
                                exerciseHeader(exercise)
                                setsCard(exercise)
                                exerciseNavigation
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    }
                }

                // Rest timer overlay
                if showRestTimer {
                    restTimerOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("End") {
                        showFinishConfirm = true
                    }
                    .foregroundColor(Brand.critical)
                }

                ToolbarItem(placement: .principal) {
                    Text(day.name)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Finish") {
                        Task { await saveAndFinish() }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(Brand.optimal)
                    .disabled(isSaving)
                }
            }
            .confirmationDialog("End workout?", isPresented: $showFinishConfirm) {
                Button("Save & Finish") {
                    Task { await saveAndFinish() }
                }
                Button("Discard", role: .destructive) {
                    cleanup()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                setupSession()
                startSessionTimer()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        HStack {
            // Timer
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(formatTime(elapsedSeconds))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundColor(Brand.accent)

            Spacer()

            // Progress
            Text("\(completedSets)/\(totalSets) sets")
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundColor(Brand.textSecondary)

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(Brand.optimal)
                        .frame(width: geo.size.width * (totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0))
                }
            }
            .frame(width: 60, height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Brand.card)
    }

    // MARK: - Exercise Header

    private func exerciseHeader(_ exercise: ExerciseSessionData) -> some View {
        VStack(spacing: 4) {
            Text("Exercise \(currentExerciseIndex + 1) of \(exerciseData.count)")
                .font(.caption)
                .foregroundColor(Brand.textMuted)

            Text(exercise.name)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Text("\(exercise.targetSets) sets × \(exercise.targetReps)")
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Sets Card

    private func setsCard(_ exercise: ExerciseSessionData) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Set")
                    .frame(width: 40, alignment: .leading)
                Text("Weight")
                    .frame(maxWidth: .infinity)
                Text("Reps")
                    .frame(maxWidth: .infinity)
                Text("")
                    .frame(width: 44)
            }
            .font(.caption.weight(.medium))
            .foregroundColor(Brand.textMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.06))

            // Set rows
            ForEach(exercise.sets.indices, id: \.self) { setIndex in
                setRow(exerciseIndex: currentExerciseIndex, setIndex: setIndex)

                if setIndex < exercise.sets.count - 1 {
                    Divider().background(Color.white.opacity(0.03))
                }
            }
        }
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func setRow(exerciseIndex: Int, setIndex: Int) -> some View {
        let set = exerciseData[exerciseIndex].sets[setIndex]

        return HStack {
            Text("\(setIndex + 1)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(set.completed ? Brand.optimal : Brand.textSecondary)
                .frame(width: 40, alignment: .leading)

            // Weight input
            TextField("—", text: Binding(
                get: { exerciseData[exerciseIndex].sets[setIndex].weightText },
                set: { exerciseData[exerciseIndex].sets[setIndex].weightText = $0 }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(Brand.elevated)
            .cornerRadius(8)
            .frame(maxWidth: .infinity)

            // Reps input
            TextField("—", text: Binding(
                get: { exerciseData[exerciseIndex].sets[setIndex].repsText },
                set: { exerciseData[exerciseIndex].sets[setIndex].repsText = $0 }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(Brand.elevated)
            .cornerRadius(8)
            .frame(maxWidth: .infinity)

            // Complete button
            Button {
                exerciseData[exerciseIndex].sets[setIndex].completed.toggle()
                if exerciseData[exerciseIndex].sets[setIndex].completed {
                    // Start rest timer
                    restSeconds = exerciseData[exerciseIndex].restSeconds
                    restRemaining = restSeconds
                    showRestTimer = true
                    startRestTimer()

                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(set.completed ? Brand.optimal : Brand.textMuted)
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Exercise Navigation

    private var exerciseNavigation: some View {
        HStack(spacing: 12) {
            if currentExerciseIndex > 0 {
                Button {
                    withAnimation { currentExerciseIndex -= 1 }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Brand.elevated)
                    .foregroundColor(Brand.textSecondary)
                    .cornerRadius(10)
                }
            }

            if currentExerciseIndex < exerciseData.count - 1 {
                Button {
                    withAnimation { currentExerciseIndex += 1 }
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Brand.accent.opacity(0.2))
                    .foregroundColor(Brand.accent)
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Rest Timer Overlay

    private var restTimerOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    stopRestTimer()
                }

            VStack(spacing: 24) {
                Text("Rest")
                    .font(.headline)
                    .foregroundColor(Brand.textSecondary)

                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: restSeconds > 0 ? Double(restRemaining) / Double(restSeconds) : 0)
                        .stroke(Brand.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text(formatTime(restRemaining))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
                .frame(width: 160, height: 160)

                // Quick-set buttons
                HStack(spacing: 12) {
                    restPresetButton(60, label: "1:00")
                    restPresetButton(90, label: "1:30")
                    restPresetButton(120, label: "2:00")
                    restPresetButton(180, label: "3:00")
                }

                Button {
                    stopRestTimer()
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Brand.elevated)
                        .foregroundColor(Brand.textSecondary)
                        .cornerRadius(10)
                }
            }
            .padding(32)
        }
    }

    private func restPresetButton(_ seconds: Int, label: String) -> some View {
        Button {
            restSeconds = seconds
            restRemaining = seconds
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(restSeconds == seconds ? Brand.accent.opacity(0.2) : Brand.elevated)
                .foregroundColor(restSeconds == seconds ? Brand.accent : Brand.textMuted)
                .cornerRadius(8)
        }
    }

    // MARK: - Setup & Timers

    private func setupSession() {
        guard let exercises = day.exercises else { return }

        exerciseData = exercises.sorted(by: { ($0.order ?? 0) < ($1.order ?? 0) }).map { planEx in
            ExerciseSessionData(
                name: planEx.name,
                targetSets: planEx.sets ?? 3,
                targetReps: planEx.reps ?? "8-12",
                restSeconds: planEx.restSeconds ?? 90,
                sets: (0..<(planEx.sets ?? 3)).map { _ in
                    SetSessionData()
                }
            )
        }
    }

    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func startRestTimer() {
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if restRemaining > 0 {
                restRemaining -= 1
            } else {
                stopRestTimer()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        showRestTimer = false
    }

    private func cleanup() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        restTimer?.invalidate()
        restTimer = nil
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Save

    private func saveAndFinish() async {
        isSaving = true

        let exercises: [[String: Any]] = exerciseData.enumerated().map { index, ex in
            let sets: [[String: Any]] = ex.sets.enumerated().compactMap { setIdx, set in
                guard set.completed else { return nil }
                return [
                    "set_number": setIdx + 1,
                    "weight": Double(set.weightText) ?? 0,
                    "reps": Int(set.repsText) ?? 0,
                ]
            }
            return [
                "name": ex.name,
                "order": index + 1,
                "sets": sets,
            ]
        }

        let body: [String: Any] = [
            "type": "strength",
            "name": "\(plan.name) — \(day.name)",
            "duration": elapsedSeconds / 60,
            "date": {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f.string(from: Date())
            }(),
            "exercises": exercises,
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let _: APIResponse<Workout> = try await apiService.postRaw("/workouts", jsonData: jsonData)
            cleanup()
            dismiss()
        } catch {
            isSaving = false
        }
    }
}

// MARK: - Session Data Models

struct ExerciseSessionData {
    let name: String
    let targetSets: Int
    let targetReps: String
    let restSeconds: Int
    var sets: [SetSessionData]
}

struct SetSessionData {
    var weightText: String = ""
    var repsText: String = ""
    var completed: Bool = false
}
