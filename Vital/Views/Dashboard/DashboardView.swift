import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthService

    @State private var metrics: [DailyMetric] = []
    @State private var targets: UserTargets?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastSyncDate: Date?

    private var today: DailyMetric? {
        let todayStr = formatDate(Date())
        return metrics.first { $0.date == todayStr }
    }

    private var last7Days: [DailyMetric] {
        Array(metrics.prefix(7))
    }

    // MARK: - Recovery Score
    // HRV 50% + RHR 30% + Sleep 20%

    private var recoveryScore: Int {
        guard let m = today else { return 0 }

        // HRV score: baseline ~40ms, good ~60ms+, scale 0-100
        let hrvScore: Double = {
            guard let hrv = m.heartRateVariability else { return 0 }
            return min(max((hrv - 15) / 0.65, 0), 100)  // 15ms → 0, 80ms → 100
        }()

        // RHR score: lower is better, 50bpm → 100, 80bpm → 0
        let rhrScore: Double = {
            guard let rhr = m.restingHeartRate else { return 0 }
            return min(max((80 - rhr) / 0.3, 0), 100)  // 80 → 0, 50 → 100
        }()

        // Sleep score: 8h → 100, <5h → 0
        let sleepScore: Double = {
            guard let sleep = m.sleepHours else { return 0 }
            return min(max((sleep - 4) / 0.04, 0), 100)  // 4h → 0, 8h → 100
        }()

        let score = hrvScore * 0.5 + rhrScore * 0.3 + sleepScore * 0.2
        return Int(score.rounded())
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
                Color(hex: 0x0A0A0C).ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            recoveryCard
                            activityCard
                            trendsCard
                            syncIndicator
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
                            .foregroundColor(Color(hex: 0xA0A0B0))
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
                    .foregroundColor(Color(hex: 0xA0A0B0))

                Spacer()

                if streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: 0xFFB547))
                        Text("\(streakDays)d streak")
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .foregroundColor(Color(hex: 0xFFB547))
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
        .background(Color(hex: 0x141418))
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
                .foregroundColor(Color(hex: 0x606070))
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color(hex: 0x606070))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Activity")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: 0xA0A0B0))
                Spacer()
            }

            MacroBar(
                label: "Steps",
                current: today?.steps ?? 0,
                target: Double(targets?.steps ?? 10000),
                color: Color(hex: 0x00B4D8),
                unit: ""
            )

            MacroBar(
                label: "Exercise",
                current: today?.exerciseMinutes ?? 0,
                target: Double(targets?.exerciseMinutes ?? 30),
                color: Color(hex: 0x00D68F),
                unit: "min"
            )

            MacroBar(
                label: "Calories",
                current: today?.activeEnergy ?? 0,
                target: Double(targets?.calories ?? 2500),
                color: Color(hex: 0xFF4757),
                unit: "kcal"
            )
        }
        .padding(20)
        .background(Color(hex: 0x141418))
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
                    .foregroundColor(Color(hex: 0xA0A0B0))
                Spacer()
            }

            let hrvData = last7Days.reversed().compactMap { $0.heartRateVariability }
            SparklineChart(
                dataPoints: hrvData,
                color: Color(hex: 0x8B5CF6),
                label: "HRV",
                unit: "ms",
                latestValue: today?.heartRateVariability.map { String(format: "%.0f", $0) } ?? "—"
            )

            Divider().background(Color.white.opacity(0.06))

            let rhrData = last7Days.reversed().compactMap { $0.restingHeartRate }
            SparklineChart(
                dataPoints: rhrData,
                color: Color(hex: 0x00D68F),
                label: "Resting HR",
                unit: "bpm",
                latestValue: today?.restingHeartRate.map { String(format: "%.0f", $0) } ?? "—"
            )
        }
        .padding(20)
        .background(Color(hex: 0x141418))
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
                        .fill(Color(hex: 0x00D68F))
                        .frame(width: 6, height: 6)
                    Text("Synced \(lastSync, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(Color(hex: 0x606070))
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
                .foregroundColor(Color(hex: 0xFFB547))
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color(hex: 0xA0A0B0))
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadData() }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(hex: 0x00B4D8))
            .foregroundColor(.white)
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
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func syncAndRefresh() async {
        let syncService = SyncService(healthKitService: healthKitService, authService: authService)
        await syncService.sync()
        await loadData()
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
