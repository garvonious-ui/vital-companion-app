import SwiftUI

struct QuickLogView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    @State private var type: String = "Strength"
    @State private var name: String = ""
    @State private var duration: String = ""
    @State private var calories: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// A workout type shown in the picker. The `id` doubles as the canonical
    /// DB value — `workouts_type_check` in Postgres accepts this exact set
    /// {HIIT, Strength, Cardio, Running, Cycling, Swimming, Flexibility, Yoga,
    /// Walking, Other}. Expanded in Session 23 migration `expand_workout_types`.
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

                        // Name (optional)
                        fieldGroup("Name (optional)") {
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

                            fieldGroup("Calories (optional)") {
                                TextField("0", text: $calories)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(DarkFieldStyle())
                            }
                        }

                        // Notes
                        fieldGroup("Notes (optional)") {
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
                                    Text("Log Workout")
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
            .navigationTitle("Quick Log")
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

        let today = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.string(from: Date())
        }()

        // Build the body as a raw dictionary using the backend's camelCase field
        // names directly. APIService's typed `post(body:)` would run this through
        // `.convertToSnakeCase`, and the `/workouts` route reads camelCase —
        // plus our field names here intentionally don't match the Swift struct
        // names we'd want (backend expects `workoutName`/`durationMin`/
        // `activeCalories`, not `name`/`duration`/`calories`).
        var body: [String: Any] = [
            "type": type,
            "workoutName": name.isEmpty ? type : name.trimmingCharacters(in: .whitespaces),
            "date": today,
            "notes": notes.trimmingCharacters(in: .whitespaces),
        ]
        if let d = Int(duration) { body["durationMin"] = d }
        if let c = Int(calories), c > 0 { body["activeCalories"] = c }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let _: SuccessResponse = try await apiService.postRaw("/workouts", jsonData: jsonData)
            HapticManager.success()
            dismiss()
        } catch {
            HapticManager.error()
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            isSaving = false
        }
    }
}
