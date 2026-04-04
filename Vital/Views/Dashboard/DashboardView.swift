import SwiftUI

struct DashboardView: View {
    @Environment(APIService.self) var apiService
    @Environment(HealthKitService.self) var healthKitService
    @Environment(AuthService.self) var authService

    @State private var metrics: [DailyMetric] = []
    @State private var targets: UserTargets?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastSyncDate: Date?
    @State private var showContent = false

    private var today: DailyMetric? {
        let todayStr = formatDate(Date())
        return metrics.first { $0.date == todayStr }
    }

    private var last7Days: [DailyMetric] {
        Array(metrics.prefix(7))
    }

    // MARK: - Recovery Score (HRV 50% + RHR 30% + Sleep 20%, redistributed if missing)

    private var recoveryScore: Int {
        guard let m = today else { return 0 }

        var components: [(score: Double, weight: Double)] = []

        if let hrv = m.heartRateVariability {
            let score = min(max((hrv - 15) / 0.65, 0), 100)
            components.append((score, 0.5))
        }
        if let rhr = m.restingHeartRate {
            let score = min(max((80 - rhr) / 0.3, 0), 100)
            components.append((score, 0.3))
        }
        if let sleep = m.sleepHours {
            let score = min(max((sleep - 4) / 0.04, 0), 100)
            components.append((score, 0.2))
        }

        guard !components.isEmpty else { return 0 }

        let totalWeight = components.reduce(0.0) { $0 + $1.weight }
        let weighted = components.reduce(0.0) { $0 + $1.score * ($1.weight / totalWeight) }
        return Int(weighted.rounded())
    }

    // MARK: - Streak

    private var streakDays: Int {
        var count = 0
        let calendar = Calendar.current
        var checkDate = Date()

        for metric in metrics {
            let metricDateStr = metric.date
            let expectedStr = formatDate(checkDate)

            guard metricDateStr == expectedStr else { break }

            let hasWorkout = (metric.exerciseMinutes ?? 0) > 0
            let hasSteps = (metric.steps ?? 0) >= 9000

            if hasWorkout || hasSteps {
                count += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if isLoading {
                    DashboardSkeleton()
                        .padding(.top, 8)
                } else if let error = errorMessage {
                    errorView(error)
                } else if metrics.isEmpty {
                    EmptyStateView(
                        icon: "heart.text.square",
                        title: "No health data yet",
                        subtitle: "Sync your Apple Watch to see recovery, activity, and trends",
                        buttonTitle: "Sync Now",
                        buttonAction: { Task { await syncAndRefresh() } }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            recoveryCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 10)
                                .animation(.easeOut(duration: 0.4).delay(0.05), value: showContent)

                            activityCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 10)
                                .animation(.easeOut(duration: 0.4).delay(0.15), value: showContent)

                            trendsCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 10)
                                .animation(.easeOut(duration: 0.4).delay(0.25), value: showContent)

                            syncIndicator
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.35), value: showContent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await syncAndRefresh()
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await syncAndRefresh() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(Brand.textSecondary)
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Recovery Card

    private var recoveryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recovery")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textSecondary)

                Spacer()

                if streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(Brand.warning)
                        Text("\(streakDays)d streak")
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .foregroundColor(Brand.warning)
                    }
                }
            }

            RecoveryRing(score: recoveryScore)
                .frame(width: 140, height: 140)

            // Breakdown row
            HStack(spacing: 24) {
                recoveryDetail(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: today?.heartRateVariability.map { String(format: "%.0f", $0) + " ms" } ?? "—"
                )
                recoveryDetail(
                    icon: "heart.fill",
                    label: "RHR",
                    value: today?.restingHeartRate.map { String(format: "%.0f", $0) + " bpm" } ?? "—"
                )
                recoveryDetail(
                    icon: "moon.fill",
                    label: "Sleep",
                    value: today?.sleepHours.map { String(format: "%.1f", $0) + " hrs" } ?? "—"
                )
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

    private func recoveryDetail(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Brand.textMuted)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(Brand.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Activity")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
            }

            MacroBar(
                label: "Steps",
                current: today?.steps ?? 0,
                target: Double(targets?.steps ?? 10000),
                color: Brand.accent,
                unit: ""
            )

            MacroBar(
                label: "Exercise",
                current: today?.exerciseMinutes ?? 0,
                target: Double(targets?.exerciseMinutes ?? 30),
                color: Brand.optimal,
                unit: "min"
            )

            MacroBar(
                label: "Calories",
                current: today?.activeCalories ?? 0,
                target: Double(targets?.calories ?? 2500),
                color: Brand.critical,
                unit: "kcal"
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

    // MARK: - Trends Card

    private var trendsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("7-Day Trends")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
            }

            let hrvData = last7Days.reversed().compactMap { $0.heartRateVariability }
            SparklineChart(
                dataPoints: hrvData,
                color: Brand.secondary,
                label: "HRV",
                unit: "ms",
                latestValue: today?.heartRateVariability.map { String(format: "%.0f", $0) } ?? "—"
            )

            Divider().background(Color.white.opacity(0.06))

            let rhrData = last7Days.reversed().compactMap { $0.restingHeartRate }
            SparklineChart(
                dataPoints: rhrData,
                color: Brand.optimal,
                label: "Resting HR",
                unit: "bpm",
                latestValue: today?.restingHeartRate.map { String(format: "%.0f", $0) } ?? "—"
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

    // MARK: - Sync Indicator

    private var syncIndicator: some View {
        HStack {
            Spacer()
            if let lastSync = lastSyncDate {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Brand.optimal)
                        .frame(width: 6, height: 6)
                    Text("Synced \(lastSync, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(Brand.textMuted)
                }
            }
            Spacer()
        }
        .padding(.top, 4)
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

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let metricsResponse: APIResponse<[DailyMetric]> = apiService.get("/metrics")
            async let targetsResponse: APIResponse<UserTargets> = apiService.get("/targets")

            let (m, t) = try await (metricsResponse, targetsResponse)

            metrics = m.data ?? []
            targets = t.data
            lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
            isLoading = false
            withAnimation { showContent = true }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func syncAndRefresh() async {
        let syncService = SyncService(healthKitService: healthKitService, authService: authService)
        await syncService.sync()
        await loadData()
        HapticManager.success()
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
