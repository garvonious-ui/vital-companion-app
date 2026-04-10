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

/// Identifiable payload for `.sheet(item:)` — ensures MealFormView receives fresh prefill
/// values atomically, avoiding the stale-@State race when using `.sheet(isPresented:)`.
struct MealPrefill: Identifiable {
    let id = UUID()
    let name: String
    let calories: String
    let protein: String
    let carbs: String
    let fat: String
}

/// Payload returned by `FoodSearchView` in selection-only mode — used when
/// the search sheet is presented from the meal edit flow to swap the
/// underlying food for a database entry. Macros are already scaled by the
/// chosen serving and quantity multiplier, so the caller can apply them
/// directly to its form state.
struct MealSelection: Sendable {
    let foodName: String
    let brandName: String?
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

/// One staged item in the multi-item meal cart. Macros are already
/// scaled by serving size and quantity multiplier.
struct MealCartItem: Identifiable, Sendable {
    let id = UUID()
    let foodName: String
    let brandName: String?
    let servingDescription: String   // e.g. "1 serving × 1.5"
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

    /// When non-nil, the view runs in "selection-only" mode: the multi-item
    /// cart UI is hidden, the "Log manually instead" fallback is hidden, and
    /// the "Add to Meal" button becomes "Use This Food" — tapping it fires
    /// the callback with the scaled macros and dismisses the sheet. No DB
    /// write happens in selection mode; the caller is responsible for
    /// persisting the change (typically a PATCH to /api/nutrition via
    /// MealFormView). Used for the meal-edit "swap with database entry"
    /// flow.
    var onFoodSelected: ((MealSelection) -> Void)? = nil

    /// Convenience — true when the view was presented for selection.
    private var isSelectionMode: Bool { onFoodSelected != nil }

    @State private var searchText = ""
    @State private var results: [FoodSearchResult] = []
    @State private var isSearching = false
    @State private var selectedFood: FoodDetail?
    @State private var selectedServing: FoodServing?
    @State private var servingMultiplier = 1.0
    @State private var mealPrefill: MealPrefill?
    @State private var isSaving = false
    @State private var searchTask: Task<Void, Never>?

    // Multi-item meal cart
    @State private var mealCart: [MealCartItem] = []
    @State private var showReview = false
    @State private var showCancelConfirm = false

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
                            // "Log manually instead" is hidden in selection
                            // mode — the caller is already in an edit form
                            // where the user can tweak fields manually, so
                            // the option would be circular.
                            if !isSelectionMode {
                                Button {
                                    // Pre-fill name and go to manual form
                                    mealPrefill = MealPrefill(
                                        name: searchText,
                                        calories: "",
                                        protein: "",
                                        carbs: "",
                                        fat: ""
                                    )
                                } label: {
                                    Text("Log manually instead")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Brand.accent)
                                }
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
            .safeAreaInset(edge: .bottom) {
                // Cart bar is hidden in selection mode — selection is one food
                // at a time, no cart concept.
                if !isSelectionMode && !mealCart.isEmpty {
                    cartBar
                }
            }
            .navigationTitle("Search Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if mealCart.isEmpty {
                            dismiss()
                        } else {
                            // Confirm before discarding cart
                            showCancelConfirm = true
                        }
                    }
                    .foregroundColor(Brand.accent)
                }
            }
            .confirmationDialog("Discard meal?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                Button("Discard \(mealCart.count) item\(mealCart.count == 1 ? "" : "s")", role: .destructive) {
                    mealCart.removeAll()
                    dismiss()
                }
                Button("Keep editing", role: .cancel) {}
            }
            .onChange(of: searchText) { _, newValue in
                // Any new search query clears the previously-selected food detail so
                // the user sees the results list, not a stale serving picker.
                selectedFood = nil
                selectedServing = nil

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
            .sheet(item: $mealPrefill) { prefill in
                MealFormView(
                    date: date,
                    editingMeal: nil,
                    prefillName: prefill.name,
                    prefillCalories: prefill.calories,
                    prefillProtein: prefill.protein,
                    prefillCarbs: prefill.carbs,
                    prefillFat: prefill.fat,
                    onSaved: {
                        // Meal saved → notify the parent view (refreshes its data)
                        // and close the food search sheet so the user lands back on
                        // the screen they started from.
                        onSaved?()
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $showReview) {
                MealReviewView(
                    date: date,
                    items: $mealCart,
                    onSaved: {
                        onSaved?()
                        dismiss()
                    }
                )
                .environment(apiService)
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

                        // Primary action — branches on mode. In cart (add) mode
                        // this appends to the meal cart. In selection mode it
                        // fires the callback with the scaled macros and dismisses.
                        Button {
                            if isSelectionMode {
                                useCurrentFoodAsSelection(food: food, serving: serving)
                            } else {
                                addCurrentFoodToCart(food: food, serving: serving)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(
                                    isSelectionMode
                                        ? "Use This Food"
                                        : (mealCart.isEmpty ? "Add to Meal" : "Add Another (\(mealCart.count) so far)")
                                )
                            }
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

    // MARK: - Cart Bar

    private var cartTotalCalories: Int {
        mealCart.reduce(0) { $0 + $1.calories }
    }

    private var cartTotalProtein: Double {
        mealCart.reduce(0) { $0 + $1.protein }
    }

    private var cartBar: some View {
        Button {
            showReview = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Brand.accent)
                        .frame(width: 36, height: 36)
                    Text("\(mealCart.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Brand.bg)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(mealCart.count) item\(mealCart.count == 1 ? "" : "s") in meal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Brand.textPrimary)
                    Text("\(cartTotalCalories) cal · \(Int(cartTotalProtein))g protein")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Brand.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Review")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundColor(Brand.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Brand.elevated)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.white.opacity(0.06)),
                alignment: .top
            )
        }
    }

    // MARK: - Cart Actions

    /// Selection-mode counterpart to `addCurrentFoodToCart`. Builds a
    /// `MealSelection` from the current food/serving/multiplier, fires the
    /// `onFoodSelected` callback, and dismisses. No DB write — the caller
    /// owns persistence.
    private func useCurrentFoodAsSelection(food: FoodDetail, serving: FoodServing) {
        let mult = servingMultiplier
        let selection = MealSelection(
            foodName: food.name,
            brandName: food.brandName,
            calories: Int(Double(serving.calories) * mult),
            protein: serving.protein * mult,
            carbs: serving.carbs * mult,
            fat: serving.fat * mult
        )
        HapticManager.success()
        onFoodSelected?(selection)
        dismiss()
    }

    private func addCurrentFoodToCart(food: FoodDetail, serving: FoodServing) {
        let mult = servingMultiplier
        let item = MealCartItem(
            foodName: food.name,
            brandName: food.brandName,
            servingDescription: mult == 1.0
                ? serving.description
                : "\(serving.description) × \(String(format: "%.1f", mult))",
            calories: Int(Double(serving.calories) * mult),
            protein: serving.protein * mult,
            carbs: serving.carbs * mult,
            fat: serving.fat * mult
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            mealCart.append(item)
        }
        HapticManager.success()

        // Reset the picker so the user lands back on the results list and can add more.
        selectedFood = nil
        selectedServing = nil
        servingMultiplier = 1.0
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
            if isSelectionMode {
                // Selection mode fallback — use the list-row data directly as
                // a selection payload. Avoids opening a nested MealFormView on
                // top of the caller's edit form.
                let selection = MealSelection(
                    foodName: result.name,
                    brandName: result.brandName,
                    calories: result.calories ?? 0,
                    protein: result.protein ?? 0,
                    carbs: result.carbs ?? 0,
                    fat: result.fat ?? 0
                )
                HapticManager.success()
                onFoodSelected?(selection)
                dismiss()
            } else {
                // Fallback: pre-fill the manual form with the search result data.
                mealPrefill = MealPrefill(
                    name: result.name,
                    calories: result.calories.map { "\($0)" } ?? "",
                    protein: result.protein.map { String(format: "%.0f", $0) } ?? "",
                    carbs: result.carbs.map { String(format: "%.0f", $0) } ?? "",
                    fat: result.fat.map { String(format: "%.0f", $0) } ?? ""
                )
            }
        }
    }
}

// MARK: - Meal Review View

/// Final review + save step for a multi-item meal. Reads/writes the cart via binding so the
/// parent FoodSearchView can clear it on success.
struct MealReviewView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) private var dismiss

    let date: String
    @Binding var items: [MealCartItem]
    let onSaved: () -> Void

    @State private var mealName: String = ""
    @State private var mealType: String = "Lunch"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didInitName = false

    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack", "Shake", "Drink"]

    private var totalCalories: Int { items.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { items.reduce(0) { $0 + $1.fat } }

    /// Compose a smart default name. If all items share a brand, use "Brand: A, B, C".
    /// Otherwise, just join names. Truncate to first 3 if there are many.
    private func composedName() -> String {
        let displayItems = items.prefix(3)
        let suffix = items.count > 3 ? " + \(items.count - 3) more" : ""
        let names = displayItems.map(\.foodName).joined(separator: ", ")

        let allBrands = Set(items.compactMap { $0.brandName })
        if allBrands.count == 1, let brand = allBrands.first {
            return "\(brand): \(names)\(suffix)"
        }
        return "\(names)\(suffix)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Meal type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal Type")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Brand.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(mealTypes, id: \.self) { type in
                                        Button {
                                            mealType = type
                                            HapticManager.light()
                                        } label: {
                                            Text(type)
                                                .font(.caption.weight(.medium))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(mealType == type ? Brand.accent.opacity(0.2) : Brand.elevated)
                                                .foregroundColor(mealType == type ? Brand.accent : Brand.textSecondary)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(mealType == type ? Brand.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        // Meal name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal Name")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Brand.textSecondary)
                            TextField("Meal name", text: $mealName)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        // Items
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ITEMS (\(items.count))")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Brand.textMuted)

                            VStack(spacing: 6) {
                                ForEach(items) { item in
                                    itemRow(item)
                                }
                            }
                        }

                        // Totals
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOTALS")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Brand.textMuted)

                            HStack(spacing: 12) {
                                totalsCard("Calories", value: "\(totalCalories)", color: Brand.textPrimary)
                                totalsCard("Protein", value: "\(Int(totalProtein))g", color: Brand.accent)
                                totalsCard("Carbs", value: "\(Int(totalCarbs))g", color: Brand.secondary)
                                totalsCard("Fat", value: "\(Int(totalFat))g", color: Brand.critical)
                            }
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Brand.critical)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Brand.critical.opacity(0.1))
                                .cornerRadius(8)
                        }

                        // Save button
                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(Brand.bg)
                                } else {
                                    Text("Save Meal")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(items.isEmpty ? Brand.elevated : Brand.accent)
                            .foregroundColor(Brand.bg)
                            .cornerRadius(12)
                        }
                        .disabled(items.isEmpty || isSaving || mealName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Review Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                        .foregroundColor(Brand.accent)
                }
            }
            .onAppear {
                // Only initialize the name once so the user's edits aren't clobbered
                // when items are removed.
                if !didInitName {
                    mealName = composedName()
                    didInitName = true
                }
            }
        }
    }

    private func itemRow(_ item: MealCartItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.foodName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(1)
                Text("\(item.servingDescription) · \(item.calories) cal")
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }
            Spacer()
            Button {
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    _ = withAnimation {
                        items.remove(at: idx)
                    }
                    HapticManager.light()
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(Brand.textMuted)
            }
        }
        .padding(12)
        .background(Brand.card)
        .cornerRadius(10)
    }

    private func totalsCard(_ label: String, value: String, color: Color) -> some View {
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

    // MARK: - Save

    private func save() async {
        guard !items.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        // Build per-item breakdown for the notes field so we don't lose context.
        let breakdown = items.map { item in
            "• \(item.foodName) (\(item.servingDescription)) — \(item.calories)c, \(Int(item.protein))p, \(Int(item.carbs))c, \(Int(item.fat))f"
        }.joined(separator: "\n")
        let notes = "Multi-item meal (\(items.count) items):\n\(breakdown)"

        let body: [String: Any] = [
            "meal": mealName.trimmingCharacters(in: .whitespaces),
            "mealType": mealType,
            "date": date,
            "calories": totalCalories,
            "proteinG": totalProtein,
            "carbsG": totalCarbs,
            "fatG": totalFat,
            "notes": notes
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let _: SuccessResponse = try await apiService.postRaw("/nutrition", jsonData: jsonData)
            HapticManager.success()
            items.removeAll()
            // Only call onSaved — the parent (FoodSearchView) dismisses itself
            // in its onSaved closure, which cascades down and unmounts this
            // review sheet as a side effect. Calling dismiss() here too would
            // fire a second dismiss on an already-unmounting view, and
            // SwiftUI propagates that up the sheet chain — ending up popping
            // the user all the way back to the root tab. Classic sheet-on-sheet
            // dismissal bug.
            onSaved()
        } catch {
            HapticManager.error()
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            isSaving = false
        }
    }
}
