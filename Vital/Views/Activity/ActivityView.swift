import SwiftUI

struct ActivityView: View {
    @Environment(APIService.self) var apiService
    @Environment(AuthService.self) var authService
    @Environment(\.scenePhase) private var scenePhase

    @State private var meals: [NutritionEntry] = []
    @State private var targets: UserTargets?
    @State private var workouts: [Workout] = []
    @State private var plans: [WorkoutPlan] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showMealForm = false
    @State private var showMealScan = false
    @State private var showMealOptions = false
    @State private var showNutritionDetail = false
    @State private var showQuickLog = false
    @State private var selectedWorkout: Workout?
    @State private var selectedPlan: WorkoutPlan?
    @State private var selectedPlanDay: PlanDay?

    // Today's nutrition
    private var todayMeals: [NutritionEntry] {
        let todayStr = formatDate(Date())
        return meals.filter { $0.date.hasPrefix(todayStr) }
    }

    private var totalCalories: Int {
        todayMeals.reduce(0) { $0 + ($1.calories ?? 0) }
    }

    private var totalProtein: Double {
        todayMeals.reduce(0) { $0 + ($1.protein ?? 0) }
    }

    // Recent workouts (last 5)
    private var recentWorkouts: [Workout] {
        Array(workouts.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if isLoading {
                    ListSkeleton(count: 4)
                        .padding(.top, 16)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            nutritionSummaryCard
                            recentWorkoutsSection
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
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showQuickLog = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Brand.accent)
                    }
                }
            }
            .confirmationDialog("Log Meal", isPresented: $showMealOptions) {
                Button("📸 Scan Meal Photo") { showMealScan = true }
                Button("✏️ Log Manually") { showMealForm = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showMealForm, onDismiss: {
                Task { await loadData() }
            }) {
                MealFormView(date: formatDate(Date()), editingMeal: nil)
            }
            .sheet(isPresented: $showMealScan, onDismiss: {
                Task { await loadData() }
            }) {
                MealAnalysisView(authService: authService) {
                    Task { await loadData() }
                }
            }
            .sheet(isPresented: $showNutritionDetail, onDismiss: {
                Task { await loadData() }
            }) {
                NavigationStack {
                    NutritionView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") { showNutritionDetail = false }
                                    .foregroundColor(Brand.accent)
                            }
                        }
                }
            }
            .sheet(isPresented: $showQuickLog, onDismiss: {
                Task { await loadData() }
            }) {
                QuickLogView()
            }
            .sheet(item: $selectedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
            .fullScreenCover(item: $selectedPlanDay) { day in
                if let plan = selectedPlan {
                    WorkoutSessionView(plan: plan, day: day)
                }
            }
            .task {
                await loadData()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && !isLoading {
                    Task {
                        _ = await authService.refreshSession()
                        await loadData()
                    }
                }
            }
        }
    }

    // MARK: - Nutrition Summary Card

    private var nutritionSummaryCard: some View {
        Button {
            showNutritionDetail = true
        } label: {
            VStack(spacing: 14) {
                HStack {
                    Text("Today's Nutrition")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Brand.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Brand.textMuted)
                }

                // Calories + Protein side by side
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Calories")
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(totalCalories)")
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundColor(.white)
                            Text("/ \(targets?.calories ?? 2500)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(Brand.textMuted)
                        }
                        caloriesProgress
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Protein")
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(totalProtein))")
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundColor(.white)
                            Text("/ \(targets?.protein ?? 150)g")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(Brand.textMuted)
                        }
                        proteinProgress
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Log meal button
                Button {
                    showMealOptions = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                        Text("Log meal")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(Brand.optimal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Brand.optimal.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Brand.card)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var caloriesProgress: some View {
        let target = Double(targets?.calories ?? 2500)
        let progress = target > 0 ? min(Double(totalCalories) / target, 1.0) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: geo.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }

    private var proteinProgress: some View {
        let target = Double(targets?.protein ?? 150)
        let progress = target > 0 ? min(totalProtein / target, 1.0) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Brand.accent)
                    .frame(width: geo.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Recent Workouts

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
                if workouts.count > 5 {
                    NavigationLink {
                        WorkoutsView()
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Brand.accent)
                    }
                }
            }

            if recentWorkouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.title2)
                        .foregroundColor(Brand.textMuted)
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundColor(Brand.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Brand.card)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            } else {
                ForEach(recentWorkouts) { workout in
                    workoutRow(workout)
                }
            }

            // Quick log button
            Button {
                showQuickLog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                    Text("Quick log workout")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(Brand.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Brand.secondary.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    private func workoutRow(_ workout: Workout) -> some View {
        Button {
            selectedWorkout = workout
        } label: {
            HStack(spacing: 12) {
                workoutTypeIcon(workout.type ?? "Other")
                    .frame(width: 36, height: 36)
                    .background(workoutTypeColor(workout.type ?? "Other").opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name ?? (workout.type ?? "Workout").capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let dur = workout.duration {
                            Text("\(dur) min")
                        }
                        if let cals = workout.calories {
                            Text("· \(cals) kcal")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
                }

                Spacer()

                Text(formatWorkoutDate(workout.date))
                    .font(.caption2)
                    .foregroundColor(Brand.textMuted)
            }
            .padding(12)
            .background(Brand.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func workoutTypeIcon(_ type: String) -> some View {
        let icon: String = {
            switch type.lowercased() {
            case "strength", "weight training": return "dumbbell.fill"
            case "running", "run", "cardio": return "figure.run"
            case "cycling", "bike": return "bicycle"
            case "swimming": return "figure.pool.swim"
            case "yoga", "flexibility": return "figure.yoga"
            case "hiit": return "bolt.heart.fill"
            case "walking", "walk": return "figure.walk"
            default: return "figure.mixed.cardio"
            }
        }()
        Image(systemName: icon)
            .font(.caption)
            .foregroundColor(workoutTypeColor(type))
    }

    private func workoutTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "strength", "weight training": return Brand.secondary
        case "running", "run", "cardio": return Brand.optimal
        case "cycling", "bike": return Brand.accent
        case "hiit": return Brand.critical
        default: return Brand.warning
        }
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
            Button("Retry") { Task { await loadData() } }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Brand.accent)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
    }

    // MARK: - Data

    private func loadData() async {
        errorMessage = nil
        isLoading = meals.isEmpty && workouts.isEmpty

        do {
            async let nutritionResp: APIResponse<[NutritionEntry]> = apiService.get("/nutrition")
            async let targetsResp: APIResponse<UserTargets> = apiService.get("/targets")
            async let workoutsResp: APIResponse<[Workout]> = apiService.get("/workouts")
            async let plansResp: APIResponse<[WorkoutPlan]> = apiService.get("/plans")

            let (n, t, w, p) = try await (nutritionResp, targetsResp, workoutsResp, plansResp)
            meals = n.data ?? []
            targets = t.data
            workouts = w.data ?? []
            plans = p.data ?? []
            errorMessage = nil
            isLoading = false
        } catch let error as APIError where error.isCancelled {
            // Silently ignore cancelled requests (happens on background/foreground transitions)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func formatWorkoutDate(_ dateStr: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        guard let date = df.date(from: String(dateStr.prefix(10))) else { return dateStr }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: date)
    }
}
