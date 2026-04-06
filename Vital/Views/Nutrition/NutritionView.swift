import SwiftUI
import Charts

struct NutritionView: View {
    @Environment(APIService.self) var apiService
    @Environment(AuthService.self) var authService

    @State private var selectedDate = Date()
    @State private var meals: [NutritionEntry] = []
    @State private var targets: UserTargets?
    @State private var weeklyCalories: [DailyMetricSlim] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showMealForm = false
    @State private var showMealScan = false
    @State private var showAddOptions = false
    @State private var editingMeal: NutritionEntry?

    private let mealOrder = ["breakfast", "lunch", "dinner", "snack", "shake", "drink"]

    // MARK: - Computed

    private var dateString: String {
        formatDate(selectedDate)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var totalCalories: Double {
        meals.reduce(0) { $0 + Double($1.calories ?? 0) }
    }

    private var totalProtein: Double {
        meals.reduce(0) { $0 + ($1.protein ?? 0) }
    }

    private var totalCarbs: Double {
        meals.reduce(0) { $0 + ($1.carbs ?? 0) }
    }

    private var totalFat: Double {
        meals.reduce(0) { $0 + ($1.fat ?? 0) }
    }

    private var groupedMeals: [(String, [NutritionEntry])] {
        mealOrder.compactMap { type in
            let items = meals.filter { ($0.mealType ?? "").lowercased() == type }
            return items.isEmpty ? nil : (type, items)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        SkeletonCard(height: 50)
                        SkeletonCard(height: 100)
                        ListSkeleton(count: 3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            dateNavigator
                            macroSummaryCard
                            weeklyCalorieCard
                            mealsListCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await loadData()
                    }
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingMeal = nil
                        showAddOptions = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Brand.accent)
                    }
                }
            }
            .confirmationDialog("Log Meal", isPresented: $showAddOptions) {
                Button("📸 Scan Meal Photo") { showMealScan = true }
                Button("✏️ Log Manually") { showMealForm = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showMealForm, onDismiss: {
                Task { await loadData() }
            }) {
                MealFormView(
                    date: dateString,
                    editingMeal: editingMeal
                )
            }
            .sheet(isPresented: $showMealScan, onDismiss: {
                Task { await loadData() }
            }) {
                MealAnalysisView(authService: authService) {
                    Task { await loadData() }
                }
            }
            .task {
                await loadData()
            }
            .onChange(of: selectedDate) { _, _ in
                Task { await loadData() }
            }
        }
    }

    // MARK: - Date Navigator

    private var dateNavigator: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(Brand.textSecondary)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(isToday ? "Today" : selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textPrimary)
                Text(selectedDate.formatted(.dateTime.month().day()))
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }
            .onTapGesture {
                selectedDate = Date()
            }

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(isToday ? Brand.textMuted.opacity(0.3) : Brand.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .disabled(isToday)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Macro Summary Card

    private var macroSummaryCard: some View {
        VStack(spacing: 14) {
            MacroBar(
                label: "Calories",
                current: totalCalories,
                target: Double(targets?.calories ?? 2500),
                color: Brand.accent,
                unit: "kcal"
            )

            MacroBar(
                label: "Protein",
                current: totalProtein,
                target: Double(targets?.protein ?? 180),
                color: Brand.optimal,
                unit: "g"
            )

            MacroBar(
                label: "Carbs",
                current: totalCarbs,
                target: Double(targets?.carbs ?? 250),
                color: Brand.warning,
                unit: "g"
            )

            MacroBar(
                label: "Fat",
                current: totalFat,
                target: Double(targets?.fat ?? 80),
                color: Brand.secondary,
                unit: "g"
            )
        }
        .padding(20)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Weekly Calorie Chart

    private var weeklyCalorieCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Brand.textSecondary)

            if weeklyCalories.count >= 2 {
                Chart {
                    if let target = targets?.calories {
                        RuleMark(y: .value("Target", target))
                            .foregroundStyle(Brand.textMuted.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }

                    ForEach(weeklyCalories) { day in
                        BarMark(
                            x: .value("Day", day.label),
                            y: .value("Calories", day.value)
                        )
                        .foregroundStyle(
                            day.label == dayLabel(selectedDate)
                                ? Brand.accent
                                : Brand.accent.opacity(0.4)
                        )
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.caption2)
                                    .foregroundColor(Brand.textMuted)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(String.self) {
                                Text(v)
                                    .font(.caption2)
                                    .foregroundColor(Brand.textMuted)
                            }
                        }
                    }
                }
                .frame(height: 120)
            } else {
                HStack {
                    Spacer()
                    Text("Log meals to see your weekly trend")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                    Spacer()
                }
                .frame(height: 80)
            }
        }
        .padding(20)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Meals List

    private var mealsListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if groupedMeals.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(Brand.textMuted)
                    Text("No meals logged")
                        .font(.subheadline)
                        .foregroundColor(Brand.textMuted)
                    Button {
                        editingMeal = nil
                        showMealForm = true
                    } label: {
                        Text("Log a Meal")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Brand.accent)
                            .foregroundColor(Brand.textPrimary)
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Brand.card)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            } else {
                ForEach(groupedMeals, id: \.0) { mealType, items in
                    mealGroupSection(type: mealType, items: items)
                }
            }
        }
    }

    private func mealGroupSection(type: String, items: [NutritionEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                mealTypeIcon(type)
                Text(type.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textPrimary)

                Spacer()

                let subtotal = items.reduce(0) { $0 + ($1.calories ?? 0) }
                Text("\(subtotal) kcal")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(Brand.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Items
            ForEach(items) { meal in
                mealRow(meal)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
            .animation(.easeInOut(duration: 0.25), value: items.map(\.id))

            Spacer().frame(height: 8)
        }
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func mealRow(_ meal: NutritionEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline)
                    .foregroundColor(Brand.textPrimary)

                HStack(spacing: 8) {
                    if let cal = meal.calories {
                        Text("\(cal) kcal")
                            .foregroundColor(Brand.accent)
                    }
                    if let p = meal.protein {
                        Text("\(Int(p))P")
                            .foregroundColor(Brand.optimal)
                    }
                    if let c = meal.carbs {
                        Text("\(Int(c))C")
                            .foregroundColor(Brand.warning)
                    }
                    if let f = meal.fat {
                        Text("\(Int(f))F")
                            .foregroundColor(Brand.secondary)
                    }
                }
                .font(.caption2.weight(.medium))
                .monospacedDigit()
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            editingMeal = meal
            showMealForm = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await deleteMeal(meal) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func mealTypeIcon(_ type: String) -> some View {
        let (icon, color): (String, Color) = {
            switch type.lowercased() {
            case "breakfast": return ("sunrise.fill", Brand.warning)
            case "lunch": return ("sun.max.fill", Brand.accent)
            case "dinner": return ("moon.fill", Brand.secondary)
            case "snack": return ("leaf.fill", Brand.optimal)
            case "shake": return ("cup.and.saucer.fill", Brand.accent)
            case "drink": return ("mug.fill", Brand.accent)
            default: return ("fork.knife", Brand.textSecondary)
            }
        }()

        Image(systemName: icon)
            .font(.caption)
            .foregroundColor(color)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(Brand.warning)
            Text(message)
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadData() }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Brand.accent)
            .foregroundColor(Brand.textPrimary)
            .cornerRadius(10)
        }
        .padding()
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = meals.isEmpty
        errorMessage = nil

        do {
            let dateParam = [URLQueryItem(name: "date", value: dateString)]
            async let nutritionResp: APIResponse<[NutritionEntry]> = apiService.get("/nutrition", queryItems: dateParam)
            async let targetsResp: APIResponse<UserTargets> = apiService.get("/targets")

            let (n, t) = try await (nutritionResp, targetsResp)
            meals = n.data ?? []
            targets = t.data

            await loadWeeklyCalories()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadWeeklyCalories() async {
        let calendar = Calendar.current
        var days: [DailyMetricSlim] = []

        // Get start of the week (Monday)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!

        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let dayStr = formatDate(day)
            let label = dayLabel(day)

            // Find calories from meals if it's the selected date, otherwise fetch
            if dayStr == dateString {
                days.append(DailyMetricSlim(label: label, value: Int(totalCalories), date: dayStr))
            } else {
                // Use a quick fetch for each day
                do {
                    let resp: APIResponse<[NutritionEntry]> = try await apiService.get("/nutrition", queryItems: [URLQueryItem(name: "date", value: dayStr)])
                    let cals = (resp.data ?? []).reduce(0) { $0 + ($1.calories ?? 0) }
                    days.append(DailyMetricSlim(label: label, value: cals, date: dayStr))
                } catch {
                    days.append(DailyMetricSlim(label: label, value: 0, date: dayStr))
                }
            }
        }

        weeklyCalories = days
    }

    private func deleteMeal(_ meal: NutritionEntry) async {
        do {
            let _: APIResponse<String?> = try await apiService.delete("/nutrition", queryItems: [URLQueryItem(name: "id", value: meal.id)])
            meals.removeAll { $0.id == meal.id }
            HapticManager.medium()
        } catch {
            HapticManager.error()
            errorMessage = error.localizedDescription
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Weekly Chart Model

struct DailyMetricSlim: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let date: String
}
