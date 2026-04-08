import SwiftUI

struct FoodSearchResult: Codable, Identifiable, Sendable {
    var id: String { foodId }
    let foodId: String
    let name: String
    let brandName: String?
    let type: String
    let description: String
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let servingSize: String?
}

struct FoodDetail: Codable, Sendable {
    let foodId: String
    let name: String
    let brandName: String?
    let type: String
    let servings: [FoodServing]
}

struct FoodServing: Codable, Identifiable, Sendable {
    var id: String { servingId }
    let servingId: String
    let description: String
    let metricAmount: Double?
    let metricUnit: String?
    let numberOfUnits: Double?
    let measurementDescription: String?
    let isDefault: Bool
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct FoodSearchView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) private var dismiss

    let date: String
    let onSaved: (() -> Void)?

    @State private var searchText = ""
    @State private var results: [FoodSearchResult] = []
    @State private var isSearching = false
    @State private var selectedFood: FoodDetail?
    @State private var selectedServing: FoodServing?
    @State private var servingMultiplier = 1.0
    @State private var showMealForm = false
    @State private var isSaving = false
    @State private var searchTask: Task<Void, Never>?

    // Pre-filled values for MealFormView
    @State private var prefillName = ""
    @State private var prefillCalories = ""
    @State private var prefillProtein = ""
    @State private var prefillCarbs = ""
    @State private var prefillFat = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Brand.textMuted)
                        TextField("Search foods...", text: $searchText)
                            .font(.subheadline)
                            .foregroundColor(Brand.textPrimary)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Brand.card)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if isSearching {
                        Spacer()
                        ProgressView().tint(Brand.accent)
                        Spacer()
                    } else if results.isEmpty && !searchText.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "fork.knife")
                                .font(.title)
                                .foregroundColor(Brand.textMuted)
                            Text("No results for \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundColor(Brand.textSecondary)
                            Button {
                                // Pre-fill name and go to manual form
                                prefillName = searchText
                                showMealForm = true
                            } label: {
                                Text("Log manually instead")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Brand.accent)
                            }
                        }
                        Spacer()
                    } else if selectedFood != nil {
                        servingPickerView
                    } else {
                        // Results list
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(results) { result in
                                    resultRow(result)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                    }
                }
            }
            .navigationTitle("Search Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.accent)
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard newValue.trimmingCharacters(in: .whitespaces).count >= 2 else {
                    results = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    if !Task.isCancelled {
                        await search(query: newValue)
                    }
                }
            }
            .sheet(isPresented: $showMealForm) {
                MealFormView(
                    date: date,
                    editingMeal: nil,
                    prefillName: prefillName,
                    prefillCalories: prefillCalories,
                    prefillProtein: prefillProtein,
                    prefillCarbs: prefillCarbs,
                    prefillFat: prefillFat
                )
            }
        }
    }

    // MARK: - Result Row

    private func resultRow(_ result: FoodSearchResult) -> some View {
        Button {
            Task { await selectFood(result) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Brand.textPrimary)
                        .lineLimit(1)

                    if let brand = result.brandName, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(Brand.accent)
                    }

                    if let serving = result.servingSize {
                        Text("Per \(serving)")
                            .font(.caption2)
                            .foregroundColor(Brand.textMuted)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if let cal = result.calories {
                        Text("\(cal) cal")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundColor(Brand.textPrimary)
                    }
                    HStack(spacing: 6) {
                        if let p = result.protein { macroLabel("P", value: p, color: Brand.accent) }
                        if let c = result.carbs { macroLabel("C", value: c, color: Brand.secondary) }
                        if let f = result.fat { macroLabel("F", value: f, color: Brand.critical) }
                    }
                }
            }
            .padding(14)
            .background(Brand.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private func macroLabel(_ label: String, value: Double, color: Color) -> some View {
        Text("\(label):\(Int(value))")
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundColor(color)
    }

    // MARK: - Serving Picker

    private var servingPickerView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let food = selectedFood {
                    // Food name header
                    VStack(spacing: 4) {
                        Text(food.name)
                            .font(.headline)
                            .foregroundColor(Brand.textPrimary)
                        if let brand = food.brandName, !brand.isEmpty {
                            Text(brand)
                                .font(.caption)
                                .foregroundColor(Brand.accent)
                        }
                    }
                    .padding(.top, 12)

                    // Serving picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERVING SIZE")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Brand.textMuted)

                        ForEach(food.servings) { serving in
                            Button {
                                selectedServing = serving
                                servingMultiplier = 1.0
                                HapticManager.light()
                            } label: {
                                HStack {
                                    Text(serving.description)
                                        .font(.subheadline)
                                        .foregroundColor(Brand.textPrimary)
                                    Spacer()
                                    Text("\(serving.calories) cal")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundColor(Brand.textSecondary)
                                    if selectedServing?.servingId == serving.servingId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Brand.accent)
                                    }
                                }
                                .padding(12)
                                .background(selectedServing?.servingId == serving.servingId ? Brand.accent.opacity(0.1) : Brand.card)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Multiplier
                    if let serving = selectedServing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("QUANTITY")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Brand.textMuted)

                            HStack(spacing: 16) {
                                Button {
                                    if servingMultiplier > 0.5 { servingMultiplier -= 0.5 }
                                    HapticManager.light()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(Brand.accent)
                                }

                                Text(String(format: "%.1f", servingMultiplier))
                                    .font(.title2.weight(.bold).monospacedDigit())
                                    .foregroundColor(Brand.textPrimary)
                                    .frame(width: 50)

                                Button {
                                    servingMultiplier += 0.5
                                    HapticManager.light()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(Brand.accent)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // Calculated macros
                            let cal = Int(Double(serving.calories) * servingMultiplier)
                            let pro = serving.protein * servingMultiplier
                            let car = serving.carbs * servingMultiplier
                            let fat = serving.fat * servingMultiplier

                            HStack(spacing: 16) {
                                macroCard("Calories", value: "\(cal)", color: Brand.textPrimary)
                                macroCard("Protein", value: String(format: "%.0fg", pro), color: Brand.accent)
                                macroCard("Carbs", value: String(format: "%.0fg", car), color: Brand.secondary)
                                macroCard("Fat", value: String(format: "%.0fg", fat), color: Brand.critical)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Add button
                        Button {
                            prefillName = food.name
                            prefillCalories = "\(Int(Double(serving.calories) * servingMultiplier))"
                            prefillProtein = String(format: "%.0f", serving.protein * servingMultiplier)
                            prefillCarbs = String(format: "%.0f", serving.carbs * servingMultiplier)
                            prefillFat = String(format: "%.0f", serving.fat * servingMultiplier)
                            showMealForm = true
                        } label: {
                            Text("Add to Meal Log")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Brand.accent)
                                .foregroundColor(Brand.bg)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Back to search
                    Button {
                        selectedFood = nil
                        selectedServing = nil
                    } label: {
                        Text("Back to search")
                            .font(.subheadline)
                            .foregroundColor(Brand.textSecondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func macroCard(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Brand.card)
        .cornerRadius(8)
    }

    // MARK: - API

    private func search(query: String) async {
        isSearching = true
        defer { isSearching = false }

        do {
            let resp: APIResponse<[FoodSearchResult]> = try await apiService.get(
                "/nutrition/search",
                queryItems: [URLQueryItem(name: "q", value: query)]
            )
            results = resp.data ?? []
        } catch {
            print("[FoodSearch] Error: \(error)")
        }
    }

    private func selectFood(_ result: FoodSearchResult) async {
        do {
            let resp: APIResponse<FoodDetail> = try await apiService.get(
                "/nutrition/food",
                queryItems: [URLQueryItem(name: "id", value: result.foodId)]
            )
            if let food = resp.data {
                selectedFood = food
                selectedServing = food.servings.first { $0.isDefault } ?? food.servings.first
                servingMultiplier = 1.0
            }
        } catch {
            // Fallback: use search result data directly
            prefillName = result.name
            prefillCalories = result.calories.map { "\($0)" } ?? ""
            prefillProtein = result.protein.map { String(format: "%.0f", $0) } ?? ""
            prefillCarbs = result.carbs.map { String(format: "%.0f", $0) } ?? ""
            prefillFat = result.fat.map { String(format: "%.0f", $0) } ?? ""
            showMealForm = true
        }
    }
}
