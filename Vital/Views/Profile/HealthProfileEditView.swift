import SwiftUI

struct HealthProfileEditView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) private var dismiss

    let profile: UserProfile?
    let onSave: () async -> Void

    @State private var conditions: [String] = []
    @State private var medications: [String] = []
    @State private var goals: [String] = []

    @State private var newCondition = ""
    @State private var newMedication = ""
    @State private var newGoal = ""

    @State private var isSaving = false

    private let presetConditions = [
        "ADHD", "Anxiety", "Asthma", "Depression", "Diabetes",
        "High Blood Pressure", "High Cholesterol", "Hypothyroid",
        "IBS", "Insomnia", "PCOS", "Allergies"
    ]

    private let presetMedications = [
        "Adderall", "Lexapro", "Lisinopril", "Metformin",
        "Levothyroxine", "Atorvastatin", "Ozempic", "Wellbutrin",
        "Zoloft", "Omeprazole", "Amlodipine", "Losartan"
    ]

    private let presetGoals = [
        "Body Recomp", "Weight Loss", "Muscle Gain", "Better Sleep",
        "Lower Cholesterol", "General Health", "Stress Management",
        "Athletic Performance", "More Energy", "Longevity"
    ]

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    editSection(
                        title: "Conditions",
                        color: Brand.critical,
                        items: $conditions,
                        presets: presetConditions,
                        newItem: $newCondition,
                        placeholder: "Add condition..."
                    )

                    editSection(
                        title: "Medications",
                        color: Brand.accent,
                        items: $medications,
                        presets: presetMedications,
                        newItem: $newMedication,
                        placeholder: "Add medication..."
                    )

                    editSection(
                        title: "Goals",
                        color: Brand.optimal,
                        items: $goals,
                        presets: presetGoals,
                        newItem: $newGoal,
                        placeholder: "Add goal..."
                    )
                }
                .padding(16)
                .padding(.bottom, 80)
            }
            .dismissKeyboardOnDrag()
        }
        .navigationTitle("Edit Health Profile")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardToolbarDone()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundColor(Brand.accent)
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            conditions = profile?.conditions ?? []
            medications = profile?.medications ?? []
            goals = profile?.goals ?? []
        }
    }

    // MARK: - Edit Section

    private func editSection(
        title: String,
        color: Color,
        items: Binding<[String]>,
        presets: [String],
        newItem: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(Brand.textMuted)

            // Preset pills
            FlowLayout(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    let isSelected = items.wrappedValue.contains(preset)
                    Button {
                        HapticManager.light()
                        if isSelected {
                            items.wrappedValue.removeAll { $0 == preset }
                        } else {
                            items.wrappedValue.append(preset)
                        }
                    } label: {
                        Text(preset)
                            .font(.caption.weight(.medium))
                            .foregroundColor(isSelected ? .white : color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? color.opacity(0.8) : color.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
            }

            // Custom items (not in presets)
            let customItems = items.wrappedValue.filter { !presets.contains($0) }
            if !customItems.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(customItems, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white)
                            Button {
                                HapticManager.light()
                                items.wrappedValue.removeAll { $0 == item }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(color.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
            }

            // Add custom field
            HStack(spacing: 8) {
                TextField(placeholder, text: newItem)
                    .font(.subheadline)
                    .foregroundColor(Brand.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Brand.elevated)
                    .cornerRadius(8)
                    .onSubmit {
                        addCustomItem(newItem: newItem, items: items)
                    }

                if !newItem.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        addCustomItem(newItem: newItem, items: items)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
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

    private func addCustomItem(newItem: Binding<String>, items: Binding<[String]>) {
        let trimmed = newItem.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !items.wrappedValue.contains(trimmed) else { return }
        HapticManager.light()
        items.wrappedValue.append(trimmed)
        newItem.wrappedValue = ""
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let body: [String: Any] = [
                "conditions": conditions,
                "medications": medications,
                "goals": goals
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let _: SuccessResponse = try await apiService.patchRaw("/profile", jsonData: jsonData)
            HapticManager.success()
            await onSave()
            dismiss()
        } catch {
            print("[HealthProfile] Failed to save: \(error)")
        }
    }
}
