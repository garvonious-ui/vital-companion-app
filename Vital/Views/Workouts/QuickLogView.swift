import SwiftUI

struct QuickLogView: View {
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) var dismiss

    @State private var type: String = "strength"
    @State private var name: String = ""
    @State private var duration: String = ""
    @State private var calories: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let workoutTypes = [
        ("strength", "dumbbell.fill"),
        ("running", "figure.run"),
        ("cycling", "bicycle"),
        ("swimming", "figure.pool.swim"),
        ("hiit", "bolt.heart.fill"),
        ("yoga", "figure.yoga"),
        ("walking", "figure.walk"),
        ("other", "figure.mixed.cardio"),
    ]

    private var isValid: Bool {
        !duration.isEmpty && Int(duration) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A0A0C).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Type grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Color(hex: 0xA0A0B0))

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(workoutTypes, id: \.0) { wType, icon in
                                    typeButton(wType, icon: icon)
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
                                .foregroundColor(Color(hex: 0xFF4757))
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
                            .background(isValid ? Color(hex: 0x00B4D8) : Color(hex: 0x1C1C22))
                            .foregroundColor(isValid ? .white : Color(hex: 0x606070))
                            .cornerRadius(12)
                        }
                        .disabled(!isValid || isSaving)

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: 0xA0A0B0))
                }
            }
        }
    }

    private func typeButton(_ wType: String, icon: String) -> some View {
        let isSelected = type == wType
        return Button {
            type = wType
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                Text(wType.capitalized)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: 0x00B4D8).opacity(0.2) : Color(hex: 0x1C1C22))
            .foregroundColor(isSelected ? Color(hex: 0x00B4D8) : Color(hex: 0xA0A0B0))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(hex: 0x00B4D8).opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(Color(hex: 0xA0A0B0))
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

        let body = QuickLogBody(
            type: type,
            name: name.isEmpty ? type.capitalized : name.trimmingCharacters(in: .whitespaces),
            duration: Int(duration) ?? 0,
            calories: Int(calories) ?? 0,
            date: today,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )

        do {
            let _: APIResponse<Workout> = try await apiService.post("/workouts", body: body)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

struct QuickLogBody: Codable {
    let type: String
    let name: String
    let duration: Int
    let calories: Int
    let date: String
    let notes: String
}
