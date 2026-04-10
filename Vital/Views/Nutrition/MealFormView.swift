import SwiftUI

struct MealFormView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    let date: String
    let editingMeal: NutritionEntry?

    // Optional prefill values from FoodSearchView
    var prefillName: String = ""
    var prefillCalories: String = ""
    var prefillProtein: String = ""
    var prefillCarbs: String = ""
    var prefillFat: String = ""

    // Optional callback fired after a successful save (before dismiss)
    var onSaved: (() -> Void)? = nil

    // Optional callback fired when the user confirms delete in edit mode.
    // The parent is responsible for calling the DELETE API and removing the
    // meal from its local state.
    var onDeleted: (() -> Void)? = nil

    @State private var showDeleteConfirm = false

    @State private var name: String = ""
    @State private var mealType: String = "Lunch"
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Must match the `nutrition_log_meal_type_check` CHECK constraint in the DB.
    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack", "Shake", "Drink"]

    private var isEditing: Bool { editingMeal != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Meal type picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal Type")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Brand.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(mealTypes, id: \.self) { type in
                                        mealTypeChip(type)
                                    }
                                }
                            }
                        }

                        // Name field
                        fieldGroup("Name") {
                            TextField("e.g. Grilled chicken breast", text: $name)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        // Macro fields
                        HStack(spacing: 12) {
                            fieldGroup("Calories") {
                                TextField("0", text: $calories)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(DarkFieldStyle())
                            }

                            fieldGroup("Protein (g)") {
                                TextField("0", text: $protein)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(DarkFieldStyle())
                            }
                        }

                        HStack(spacing: 12) {
                            fieldGroup("Carbs (g)") {
                                TextField("0", text: $carbs)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(DarkFieldStyle())
                            }

                            fieldGroup("Fat (g)") {
                                TextField("0", text: $fat)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(DarkFieldStyle())
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Brand.critical)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Save button
                        Button {
                            Task { await save() }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isEditing ? "Update Meal" : "Log Meal")
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

                        // Delete button (edit mode only)
                        if isEditing && onDeleted != nil {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Delete Meal")
                                }
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(Brand.critical)
                            }
                            .padding(.top, 4)
                        }

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEditing ? "Edit Meal" : "Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.textSecondary)
                }
            }
            .confirmationDialog(
                "Delete this meal?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDeleted?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
            .onAppear {
                if let meal = editingMeal {
                    name = meal.name
                    // Normalize to capitalized to match the DB CHECK constraint and the
                    // chip array. Tolerates legacy lowercase values from old data.
                    mealType = (meal.mealType ?? "Snack").capitalized
                    calories = meal.calories.map { String($0) } ?? ""
                    protein = meal.protein.map { String(Int($0)) } ?? ""
                    carbs = meal.carbs.map { String(Int($0)) } ?? ""
                    fat = meal.fat.map { String(Int($0)) } ?? ""
                } else if !prefillName.isEmpty {
                    name = prefillName
                    calories = prefillCalories
                    protein = prefillProtein
                    carbs = prefillCarbs
                    fat = prefillFat
                }
            }
        }
    }

    // MARK: - Meal Type Chip

    private func mealTypeChip(_ type: String) -> some View {
        let isSelected = mealType == type

        return Button {
            mealType = type
        } label: {
            Text(type.capitalized)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Brand.accent.opacity(0.2) : Brand.elevated)
                .foregroundColor(isSelected ? Brand.accent : Brand.textSecondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Brand.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
    }

    // MARK: - Field Group

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(Brand.textSecondary)
            content()
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil

        // Build the body as a raw dictionary so the camelCase keys reach the backend
        // unmodified. APIService's typed `post(body:)` would convert these to snake_case
        // via `.convertToSnakeCase`, which the `/nutrition` route silently drops — every
        // write path in this app must use `postRaw` with a `[String: Any]` dict.
        var body: [String: Any] = [
            "meal": name.trimmingCharacters(in: .whitespaces),
            "mealType": mealType,
            "date": date
        ]
        if let cal = Int(calories) { body["calories"] = cal }
        if let p = Double(protein) { body["proteinG"] = p }
        if let c = Double(carbs) { body["carbsG"] = c }
        if let f = Double(fat) { body["fatG"] = f }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            if let meal = editingMeal {
                // PATCH expects the id in the body for updateNutritionEntry
                var patchBody = body
                patchBody["id"] = meal.id
                let patchData = try JSONSerialization.data(withJSONObject: patchBody)
                let _: SuccessResponse = try await apiService.patchRaw("/nutrition", jsonData: patchData)
            } else {
                let _: SuccessResponse = try await apiService.postRaw("/nutrition", jsonData: jsonData)
            }
            HapticManager.success()
            onSaved?()
            dismiss()
        } catch {
            HapticManager.error()
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Dark Text Field Style

struct DarkFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Brand.elevated)
            .cornerRadius(10)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}
