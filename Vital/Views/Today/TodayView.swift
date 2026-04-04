import SwiftUI

struct TodayView: View {
    @Environment(APIService.self) var apiService
    @Environment(HealthKitService.self) var healthKitService
    @Environment(AuthService.self) var authService
    @Environment(SyncService.self) var syncService

    @Environment(\.scenePhase) private var scenePhase

    @State private var metrics: [DailyMetric] = []
    @State private var targets: UserTargets?
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showContent = false
    @State private var showChat = false
    @State private var showMealForm = false
    @State private var showMealScan = false
    @State private var showMealOptions = false
    @State private var showRecoveryInfo = false
    @State private var showWater = false
    @State private var animateMetrics = false
    @State private var animateCalories = false
    @State private var recoveryAnimationKey = UUID()
    @State private var lastLoadTime: Date = .distantPast

    private var todayDateString: String {
        formatDate(Date())
    }

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

        // Build available components with base weights
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

        // Redistribute weights proportionally across available components
        let totalWeight = components.reduce(0.0) { $0 + $1.weight }
        let weighted = components.reduce(0.0) { $0 + $1.score * ($1.weight / totalWeight) }
        return Int(weighted.rounded())
    }

    // MARK: - Recovery Verdict

    private var verdictText: String {
        let score = recoveryScore
        let sleep = today?.sleepHours
        let sleepStr = sleep.map { String(format: "%.1f", $0) } ?? "—"

        // HRV delta vs 7-day average
        let hrvValues = last7Days.compactMap { $0.heartRateVariability }
        let hrvAvg = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
        let hrvDelta: Int? = {
            guard let current = today?.heartRateVariability, let avg = hrvAvg else { return nil }
            return Int((current - avg).rounded())
        }()

        if today == nil {
            return "No data yet today. Sync your Apple Watch to see your recovery."
        }

        if score >= 80 {
            return "Your recovery is strong — you slept \(sleepStr) hrs and HRV is above baseline. Great day to push it."
        } else if score >= 60 {
            return "Recovery is solid — \(sleepStr) hrs of sleep. Your body is ready for a normal training day."
        } else if score >= 40 {
            var reasons: [String] = []
            if let s = sleep, s < 6.5 { reasons.append("short sleep (\(sleepStr) hrs)") }
            if let d = hrvDelta, d < -5 { reasons.append("low HRV") }
            if let rhr = today?.restingHeartRate, let avg = last7Days.compactMap({ $0.restingHeartRate }).average, rhr > avg + 3 {
                reasons.append("elevated heart rate")
            }
            let reasonStr = reasons.isEmpty ? "mixed signals today" : reasons.joined(separator: " and ")
            return "Moderate recovery — \(reasonStr). Listen to your body and don't overdo it."
        } else {
            return "Low recovery — your body needs rest. Consider a light walk or stretching instead of intense training."
        }
    }

    // MARK: - HRV Delta

    private var hrvDeltaVsAvg: Int? {
        let hrvValues = last7Days.compactMap { $0.heartRateVariability }
        guard let current = today?.heartRateVariability, hrvValues.count >= 2 else { return nil }
        let avg = hrvValues.reduce(0, +) / Double(hrvValues.count)
        return Int((current - avg).rounded())
    }

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = profile?.name?.components(separatedBy: " ").first ?? ""
        let nameStr = name.isEmpty ? "" : ", \(name)"
        if hour < 12 { return "Good morning\(nameStr)" }
        if hour < 17 { return "Good afternoon\(nameStr)" }
        return "Good evening\(nameStr)"
    }

    private var dateSubtitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
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
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Header
                            headerSection
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.05), value: showContent)

                            // Recovery card with verdict
                            recoveryCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 10)
                                .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                            // Key metrics grid
                            metricsGrid
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 10)
                                .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)

                            // Active calories
                            caloriesBar
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.25), value: showContent)

                            // Quick actions
                            quickActions
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.3), value: showContent)

                            // Ask Vital
                            askVitalButton
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
            .navigationBarHidden(true)
            .sheet(isPresented: $showChat) {
                NavigationStack {
                    ChatHistoryView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") { showChat = false }
                                    .foregroundColor(Brand.accent)
                            }
                        }
                }
            }
            .confirmationDialog("Log Meal", isPresented: $showMealOptions) {
                Button("📸 Scan Meal Photo") { showMealScan = true }
                Button("✏️ Log Manually") { showMealForm = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showMealForm) {
                MealFormView(date: todayDateString, editingMeal: nil)
            }
            .sheet(isPresented: $showMealScan) {
                MealAnalysisView(authService: authService)
            }
.sheet(isPresented: $showWater) {
                WaterQuickAddView()
            }
            .task {
                await loadData()
                lastLoadTime = Date()
            }
            .onChange(of: syncService.isSyncing) { _, syncing in
                // Only reload after sync if last load was >3s ago (avoids double-load on launch)
                if !syncing && Date().timeIntervalSince(lastLoadTime) > 3 {
                    Task {
                        await loadData()
                        lastLoadTime = Date()
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Retry loading when returning to foreground if in error state
                if newPhase == .active && errorMessage != nil {
                    Task {
                        await loadData()
                        lastLoadTime = Date()
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.title2.weight(.bold))
                .foregroundColor(Brand.textPrimary)
            Text(dateSubtitle)
                .font(.subheadline)
                .foregroundColor(Brand.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Recovery Card

    private var recoveryCard: some View {
        VStack(spacing: 16) {
            RecoveryRing(score: recoveryScore)
                .frame(width: 150, height: 150)
                .id(recoveryAnimationKey)

            // Recovery label + info button
            HStack(spacing: 6) {
                Text("RECOVERY")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Brand.textMuted)
                Button {
                    showRecoveryInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }
            }

            Text(verdictText)
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .sheet(isPresented: $showRecoveryInfo) {
            recoveryInfoSheet
        }
    }

    // MARK: - Recovery Info Sheet

    private var recoveryInfoSheet: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("How Recovery Score Works")
                            .font(.title3.weight(.bold))
                            .foregroundColor(Brand.textPrimary)

                        Text("Your recovery score (0–100) measures how ready your body is to perform. It's calculated from three metrics synced from your Apple Watch:")
                            .font(.subheadline)
                            .foregroundColor(Brand.textSecondary)

                        recoveryInfoRow(
                            icon: "waveform.path.ecg",
                            color: Brand.accent,
                            title: "Heart Rate Variability (50%)",
                            desc: "Higher HRV means your nervous system is recovered and adaptable. Range: 15–80+ ms."
                        )

                        recoveryInfoRow(
                            icon: "heart.fill",
                            color: Brand.critical,
                            title: "Resting Heart Rate (30%)",
                            desc: "Lower resting HR indicates better cardiovascular fitness and recovery. Range: 50–80 bpm."
                        )

                        recoveryInfoRow(
                            icon: "moon.fill",
                            color: Brand.secondary,
                            title: "Sleep Duration (20%)",
                            desc: "More sleep gives your body more time to repair. Optimal: 7–8+ hours."
                        )

                        Divider().background(Color.white.opacity(0.06))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Score Ranges")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Brand.textPrimary)
                            scoreRange("80–100", "Strong", "Great day to push hard", Brand.optimal)
                            scoreRange("60–79", "Solid", "Normal training day", Brand.accent)
                            scoreRange("40–59", "Moderate", "Listen to your body", Brand.warning)
                            scoreRange("0–39", "Low", "Rest or light activity", Brand.critical)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showRecoveryInfo = false }
                        .foregroundColor(Brand.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func recoveryInfoRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textPrimary)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Brand.textSecondary)
            }
        }
    }

    private func scoreRange(_ range: String, _ label: String, _ desc: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(range)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundColor(Brand.textPrimary)
                .frame(width: 50, alignment: .leading)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(color)
                .frame(width: 65, alignment: .leading)
            Text(desc)
                .font(.caption)
                .foregroundColor(Brand.textMuted)
        }
    }

    // MARK: - Metrics Grid (2x2)

    private var metricsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            NavigationLink {
                SleepDetailView()
            } label: {
                metricCard(
                    icon: "moon.fill",
                    iconColor: Brand.secondary,
                    label: "Sleep",
                    value: today?.sleepHours.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "hrs",
                    subtitle: sleepQualityLabel
                )
            }
            .scaleEffect(animateMetrics ? 1.0 : 0.92)
            .opacity(animateMetrics ? 1.0 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.05), value: animateMetrics)

            NavigationLink {
                MetricDetailView(config: .restingHR, metrics: metrics)
            } label: {
                metricCard(
                    icon: "heart.fill",
                    iconColor: Brand.critical,
                    label: "Resting HR",
                    value: today?.restingHeartRate.map { String(format: "%.0f", $0) } ?? "—",
                    unit: "bpm",
                    subtitle: nil
                )
            }
            .scaleEffect(animateMetrics ? 1.0 : 0.92)
            .opacity(animateMetrics ? 1.0 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.12), value: animateMetrics)

            NavigationLink {
                MetricDetailView(config: .steps, metrics: metrics)
            } label: {
                metricCard(
                    icon: "figure.walk",
                    iconColor: Brand.optimal,
                    label: "Steps",
                    value: today?.steps.map { formatNumber($0) } ?? "—",
                    unit: "",
                    subtitle: targets?.steps.map { "of \(formatNumber(Double($0)))" }
                )
            }
            .scaleEffect(animateMetrics ? 1.0 : 0.92)
            .opacity(animateMetrics ? 1.0 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.19), value: animateMetrics)

            NavigationLink {
                MetricDetailView(config: .hrv, metrics: metrics)
            } label: {
                metricCard(
                    icon: "waveform.path.ecg",
                    iconColor: Brand.accent,
                    label: "HRV",
                    value: today?.heartRateVariability.map { String(format: "%.0f", $0) } ?? "—",
                    unit: "ms",
                    subtitle: hrvDeltaLabel
                )
            }
            .scaleEffect(animateMetrics ? 1.0 : 0.92)
            .opacity(animateMetrics ? 1.0 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.26), value: animateMetrics)
        }
    }

    private var sleepQualityLabel: String? {
        guard let hours = today?.sleepHours else { return nil }
        if hours >= 7.5 { return "Great" }
        if hours >= 6.5 { return "Good" }
        if hours >= 5.5 { return "Fair" }
        return "Low"
    }

    private var hrvDeltaLabel: String? {
        guard let delta = hrvDeltaVsAvg else { return nil }
        if delta >= 0 { return "+\(delta) vs avg" }
        return "\(delta) vs avg"
    }

    private func metricCard(icon: String, iconColor: Color, label: String, value: String, unit: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Brand.textMuted)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundColor(Brand.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }
            }

            Text(subtitle ?? " ")
                .font(.caption2)
                .foregroundColor(subtitle != nil ? subtitleColor(subtitle!) : .clear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Brand.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func subtitleColor(_ text: String) -> Color {
        if text.hasPrefix("+") { return Brand.optimal }
        if text.hasPrefix("-") || text.hasPrefix("−") { return Brand.warning }
        if text == "Great" || text == "Good" { return Brand.optimal }
        if text == "Low" { return Brand.critical }
        return Brand.textMuted
    }

    // MARK: - Active Calories Bar

    private var caloriesBar: some View {
        let current = today?.activeCalories ?? 0
        let target = Double(targets?.calories ?? 2500)
        let progress = target > 0 ? min(current / target, 1.0) : 0

        return NavigationLink {
            MetricDetailView(config: .activeCalories, metrics: metrics)
        } label: {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundColor(Brand.critical)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Active Calories")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Brand.textSecondary)
                    Spacer()
                    Text("\(Int(current)) / \(Int(target))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(Brand.textPrimary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Brand.critical)
                            .frame(width: geo.size.width * (animateCalories ? progress : 0), height: 6)
                            .animation(.easeOut(duration: 0.7).delay(0.1), value: animateCalories)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(14)
        .background(Brand.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        } // close NavigationLink label
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionButton(icon: "fork.knife", label: "Log meal", color: Brand.optimal) {
                showMealOptions = true
            }
            quickActionButton(icon: "drop.fill", label: "Water", color: Brand.accent) {
                showWater = true
            }
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(Brand.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Brand.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - AI Insights Button

    private var askVitalButton: some View {
        Button {
            HapticManager.medium()
            showChat = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.body)
                Text("AI Insights")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(Brand.textPrimary)
            .background(
                Brand.askVitalGradient
            )
            .cornerRadius(14)
        }
        .buttonStyle(PressScaleButtonStyle())
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
                .foregroundColor(Brand.textPrimary)
                .cornerRadius(10)
        }
        .padding()
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let metricsResp: APIResponse<[DailyMetric]> = apiService.get("/metrics")
            async let targetsResp: APIResponse<UserTargets> = apiService.get("/targets")
            async let profileResp: APIResponse<UserProfile> = apiService.get("/profile")

            let (m, t, p) = try await (metricsResp, targetsResp, profileResp)
            metrics = m.data ?? []
            targets = t.data
            profile = p.data
            isLoading = false
            withAnimation { showContent = true }
            triggerAnimations()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func syncAndRefresh() async {
        // Reset animations before refresh
        animateMetrics = false
        animateCalories = false

        // Sync HealthKit data to backend — onChange(syncService.isSyncing) will reload data
        await syncService.sync()
        HapticManager.success()
    }

    private func triggerAnimations() {
        // Reset first
        animateMetrics = false
        animateCalories = false
        recoveryAnimationKey = UUID() // Forces RecoveryRing to re-init and re-animate

        // Staggered trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { animateMetrics = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animateCalories = true
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func formatNumber(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Array Extension

extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
