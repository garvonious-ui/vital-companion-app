import SwiftUI

struct WorkoutsView: View {
    @Environment(APIService.self) var apiService

    @State private var workouts: [Workout] = []
    @State private var plans: [WorkoutPlan] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showQuickLog = false
    @State private var selectedWorkout: Workout?
    @State private var selectedPlan: WorkoutPlan?
    @State private var selectedPlanDay: PlanDay?

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if isLoading {
                    ListSkeleton(count: 4)
                        .padding(.top, 16)
                } else if let error = errorMessage {
                    errorView(error)
                } else if workouts.isEmpty && plans.isEmpty {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "No workouts yet",
                        subtitle: "Log your first workout to start tracking progress",
                        buttonTitle: "Quick Log",
                        buttonAction: { showQuickLog = true }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if !plans.isEmpty {
                                plansSection
                            }
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
            .navigationTitle("Workouts")
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
        }
    }

    // MARK: - Plans Section

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Plans")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Brand.textSecondary)

            ForEach(plans) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    if let days = plan.planData?.days {
                        Text("\(days.filter { !($0.isRest ?? false) }.count) days/week")
                            .font(.caption)
                            .foregroundColor(Brand.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundColor(Brand.secondary.opacity(0.6))
            }

            if let notes = plan.planData?.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
                    .lineLimit(2)
            }

            // Day buttons
            if let days = plan.planData?.days, !days.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(days) { day in
                            Button {
                                selectedPlan = plan
                                selectedPlanDay = day
                            } label: {
                                VStack(spacing: 4) {
                                    Text("Day \(day.dayNumber)")
                                        .font(.caption2.weight(.semibold))
                                    Text(day.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Brand.secondary.opacity(0.15))
                                .foregroundColor(Brand.secondary)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Recent Workouts

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
            }

            if workouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.title2)
                        .foregroundColor(Brand.textMuted)
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundColor(Brand.textMuted)
                    Button {
                        showQuickLog = true
                    } label: {
                        Text("Log a Workout")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Brand.accent)
                            .foregroundColor(.white)
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
                ForEach(workouts) { workout in
                    workoutRow(workout)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .animation(.easeOut(duration: 0.3), value: workouts.map(\.id))
            }
        }
    }

    private func workoutRow(_ workout: Workout) -> some View {
        Button {
            selectedWorkout = workout
        } label: {
            HStack(spacing: 12) {
                // Type badge
                workoutTypeIcon(workout.type ?? "Other")
                    .frame(width: 40, height: 40)
                    .background(workoutTypeColor(workout.type ?? "Other").opacity(0.15))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name ?? (workout.type ?? "Workout").capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        if let duration = workout.duration {
                            Label("\(duration) min", systemImage: "clock")
                        }
                        if let cals = workout.calories {
                            Label("\(cals) kcal", systemImage: "flame")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(Brand.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatWorkoutDate(workout.date))
                        .font(.caption2)
                        .foregroundColor(Brand.textMuted)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Brand.textMuted)
                }
            }
            .padding(14)
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func workoutTypeIcon(_ type: String) -> some View {
        let icon: String = {
            switch type.lowercased() {
            case "strength", "weight training", "traditional strength training":
                return "dumbbell.fill"
            case "running", "run":
                return "figure.run"
            case "cycling", "bike":
                return "bicycle"
            case "swimming", "swim":
                return "figure.pool.swim"
            case "yoga":
                return "figure.yoga"
            case "hiit":
                return "bolt.heart.fill"
            case "walking", "walk":
                return "figure.walk"
            default:
                return "figure.mixed.cardio"
            }
        }()

        Image(systemName: icon)
            .font(.body)
            .foregroundColor(workoutTypeColor(type))
    }

    private func workoutTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "strength", "weight training", "traditional strength training":
            return Brand.secondary
        case "running", "run":
            return Brand.optimal
        case "cycling", "bike":
            return Brand.accent
        case "hiit":
            return Brand.critical
        default:
            return Brand.warning
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
            Button("Retry") {
                Task { await loadData() }
            }
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
        isLoading = workouts.isEmpty && plans.isEmpty
        errorMessage = nil

        do {
            async let workoutsResp: APIResponse<[Workout]> = apiService.get("/workouts")
            async let plansResp: APIResponse<[WorkoutPlan]> = apiService.get("/plans")

            let (w, p) = try await (workoutsResp, plansResp)
            workouts = w.data ?? []
            plans = p.data ?? []
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
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
