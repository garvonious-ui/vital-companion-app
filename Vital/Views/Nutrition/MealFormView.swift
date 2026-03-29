import SwiftUI

struct MealFormView: View {
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) var dismiss

    let date: String
    let editingMeal: NutritionEntry?

    @State private var name: String = ""
    @State private var mealType: String = "lunch"
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack", "shake"]

    private var isEditing: Bool { editingMeal != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A0A0C).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Meal type picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal Type")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Color(hex: 0xA0A0B0))

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
                                .foregroundColor(Color(hex: 0xFF4757))
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
            .navigationTitle(isEditing ? "Edit Meal" : "Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: 0xA0A0B0))
                }
            }
            .onAppear {
                if let meal = editingMeal {
                    name = meal.name
                    mealType = meal.mealType.lowercased()
                    calories = meal.calories.map { String($0) } ?? ""
                    protein = meal.protein.map { String(Int($0)) } ?? ""
                    carbs = meal.carbs.map { String(Int($0)) } ?? ""
                    fat = meal.fat.map { String(Int($0)) } ?? ""
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
                .background(isSelected ? Color(hex: 0x00B4D8).opacity(0.2) : Color(hex: 0x1C1C22))
                .foregroundColor(isSelected ? Color(hex: 0x00B4D8) : Color(hex: 0xA0A0B0))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color(hex: 0x00B4D8).opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
    }

    // MARK: - Field Group

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(Color(hex: 0xA0A0B0))
            content()
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil

        let body = NutritionLogBody(
            date: date,
            mealType: mealType,
            name: name.trimmingCharacters(in: .whitespaces),
            calories: Int(calories),
            protein: Double(protein),
            carbs: Double(carbs),
            fat: Double(fat)
        )

        do {
            if let meal = editingMeal {
                // PATCH with id
                let _: APIResponse<NutritionEntry> = try await apiService.patch("/nutrition?id=\(meal.id)", body: body)
            } else {
                let _: APIResponse<NutritionEntry> = try await apiService.post("/nutrition", body: body)
            }
            dismiss()
        } catch {
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
            .background(Color(hex: 0x1C1C22))
            .cornerRadius(10)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}
