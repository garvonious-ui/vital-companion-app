import SwiftUI

struct ProfileView: View {
    @Environment(APIService.self) var apiService
    @Environment(AuthService.self) var authService

    @State private var profile: UserProfile?
    @State private var targets: UserTargets?
    @State private var metrics: [DailyMetric] = []
    @State private var labs: [LabResult] = []
    @State private var supplements: [Supplement] = []
    @State private var isLoading = true
    @State private var showChat = false
    @State private var showSignOutConfirm = false

    // Trends
    private var last7Days: [DailyMetric] {
        let sorted = metrics.sorted { $0.date < $1.date }
        return Array(sorted.suffix(7))
    }

    private var last30Days: [DailyMetric] {
        let sorted = metrics.sorted { $0.date < $1.date }
        return Array(sorted.suffix(30))
    }

    private var initials: String {
        if let name = profile?.name {
            let parts = name.split(separator: " ")
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.count > 1 ? parts.last!.prefix(1) : ""
            return "\(first)\(last)".uppercased()
        }
        return "?"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if isLoading {
                    ListSkeleton(count: 4)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            profileHeader
                            askVitalButton
                            healthRecordsCard
                            trendsCard
                            settingsCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showChat) {
                NavigationStack {
                    ChatView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") { showChat = false }
                                    .foregroundColor(Brand.accent)
                            }
                        }
                }
            }
            .confirmationDialog("Sign out of Vital?", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { await authService.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Brand.accent, Brand.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Text(initials)
                    .font(.title2.weight(.bold))
                    .foregroundColor(Brand.textPrimary)
            }

            Text(profile?.name ?? "—")
                .font(.title3.weight(.bold))
                .foregroundColor(Brand.textPrimary)

            // Subtitle: age + height + weight
            let details = profileSubtitle
            if !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var profileSubtitle: String {
        var parts: [String] = []
        if let dob = profile?.dateOfBirth, let age = ageFromDOB(dob) {
            parts.append("\(age)y")
        }
        if let h = profile?.heightInches {
            let feet = Int(h) / 12
            let inches = Int(h) % 12
            parts.append("\(feet)'\(inches)\"")
        }
        if let w = profile?.weightLbs {
            parts.append("\(Int(w)) lbs")
        }
        return parts.joined(separator: " · ")
    }

    private func ageFromDOB(_ dobStr: String) -> Int? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let dob = f.date(from: dobStr) else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    // MARK: - Ask Vital

    private var askVitalButton: some View {
        Button {
            HapticManager.medium()
            showChat = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.body)
                Text("Ask Vital about your health")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(Brand.textPrimary)
            .background(
                LinearGradient(
                    colors: [Brand.accent, Brand.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Health Records

    private var healthRecordsCard: some View {
        VStack(spacing: 0) {
            Text("HEALTH RECORDS")
                .font(.caption.weight(.semibold))
                .foregroundColor(Brand.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Labs
                NavigationLink {
                    LabsView()
                } label: {
                    recordRow(
                        icon: "cross.case.fill",
                        iconColor: Brand.accent,
                        title: "Lab Results",
                        subtitle: labSubtitle,
                        trailing: labFlagBadge
                    )
                }

                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

                // Supplements
                NavigationLink {
                    SupplementsView()
                } label: {
                    recordRow(
                        icon: "pill.fill",
                        iconColor: Brand.optimal,
                        title: "Supplements",
                        subtitle: "\(supplements.filter { $0.active }.count) active",
                        trailing: EmptyView?.none
                    )
                }

                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

                // Health profile
                NavigationLink {
                    healthProfileDetail
                } label: {
                    recordRow(
                        icon: "heart.text.square.fill",
                        iconColor: Brand.secondary,
                        title: "Health Profile",
                        subtitle: "Conditions, meds, goals",
                        trailing: EmptyView?.none
                    )
                }
            }
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var labSubtitle: String {
        if labs.isEmpty { return "No results" }
        let count = labs.count
        let dateStr = labs.compactMap { $0.drawDate }.sorted().last
        let dateDisplay = dateStr.flatMap { formatDrawDate($0) } ?? ""
        return "\(count) biomarkers\(dateDisplay.isEmpty ? "" : " · drawn \(dateDisplay)")"
    }

    @ViewBuilder
    private var labFlagBadge: some View {
        let flagCount = labs.filter { $0.status == "Borderline" || $0.status == "Out of Range" || $0.status == "Critical" }.count
        if flagCount > 0 {
            Text("\(flagCount) flag\(flagCount == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Brand.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Brand.warning.opacity(0.15))
                .cornerRadius(6)
        }
    }

    private func recordRow<T: View>(icon: String, iconColor: Color, title: String, subtitle: String, trailing: T?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Brand.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }

            Spacer()

            if let trailing {
                trailing
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
        .padding(14)
    }

    // MARK: - Health Profile Detail

    private var healthProfileDetail: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let conditions = profile?.conditions, !conditions.isEmpty {
                        profileSection(title: "Conditions", items: conditions, color: Brand.critical)
                    }
                    if let meds = profile?.medications, !meds.isEmpty {
                        profileSection(title: "Medications", items: meds, color: Brand.accent)
                    }
                    if let goals = profile?.goals, !goals.isEmpty {
                        profileSection(title: "Goals", items: goals, color: Brand.optimal)
                    }

                    if (profile?.conditions ?? []).isEmpty && (profile?.medications ?? []).isEmpty && (profile?.goals ?? []).isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "heart.text.square")
                                .font(.title)
                                .foregroundColor(Brand.textMuted)
                            Text("No health profile data")
                                .font(.subheadline)
                                .foregroundColor(Brand.textMuted)
                            Text("Add conditions, medications, and goals on the web dashboard")
                                .font(.caption)
                                .foregroundColor(Brand.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Health Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func profileSection(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(Brand.textMuted)

            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption.weight(.medium))
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.12))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Trends

    private var trendsCard: some View {
        VStack(spacing: 0) {
            Text("TRENDS")
                .font(.caption.weight(.semibold))
                .foregroundColor(Brand.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Weight
                let currentWeight = last7Days.last(where: { $0.weightLbs != nil })?.weightLbs
                let weight30ago = last30Days.first(where: { $0.weightLbs != nil })?.weightLbs
                let weightDelta = (currentWeight != nil && weight30ago != nil) ? currentWeight! - weight30ago! : nil

                trendRow(
                    label: "Weight",
                    value: currentWeight.map { "\(Int($0)) lbs" } ?? "—",
                    delta: weightDelta.map { formatDelta($0, suffix: " lbs") },
                    deltaColor: weightDelta.map { $0 <= 0 ? Brand.optimal : Brand.critical } ?? Brand.textMuted
                )

                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)

                // HRV
                let hrvValues = last7Days.compactMap { $0.heartRateVariability }
                let hrvAvg = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
                let hrvPrev = Array(last30Days.prefix(7)).compactMap { $0.heartRateVariability }
                let hrvPrevAvg = hrvPrev.isEmpty ? nil : hrvPrev.reduce(0, +) / Double(hrvPrev.count)
                let hrvDirection = trendLabel(current: hrvAvg, previous: hrvPrevAvg)

                trendRow(
                    label: "HRV (7d avg)",
                    value: hrvAvg.map { "\(Int($0)) ms" } ?? "—",
                    delta: hrvDirection?.0,
                    deltaColor: hrvDirection?.1 ?? Brand.textMuted
                )

                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)

                // RHR
                let rhrValues = last7Days.compactMap { $0.restingHeartRate }
                let rhrAvg = rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count)
                let rhrPrev = Array(last30Days.prefix(7)).compactMap { $0.restingHeartRate }
                let rhrPrevAvg = rhrPrev.isEmpty ? nil : rhrPrev.reduce(0, +) / Double(rhrPrev.count)
                let rhrDirection = trendLabel(current: rhrAvg, previous: rhrPrevAvg, lowerIsBetter: true)

                trendRow(
                    label: "Resting HR (7d avg)",
                    value: rhrAvg.map { "\(Int($0)) bpm" } ?? "—",
                    delta: rhrDirection?.0,
                    deltaColor: rhrDirection?.1 ?? Brand.textMuted
                )
            }
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func trendRow(label: String, value: String, delta: String?, deltaColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Brand.textPrimary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(Brand.textPrimary)
            if let delta {
                Text(delta)
                    .font(.caption.weight(.medium))
                    .foregroundColor(deltaColor)
            }
        }
        .padding(14)
    }

    private func formatDelta(_ value: Double, suffix: String) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded > 0 { return "+\(rounded)\(suffix)" }
        return "\(rounded)\(suffix)"
    }

    private func trendLabel(current: Double?, previous: Double?, lowerIsBetter: Bool = false) -> (String, Color)? {
        guard let c = current, let p = previous else { return nil }
        let diff = c - p
        let pct = p > 0 ? abs(diff / p) : 0
        if pct < 0.02 { return ("Stable", Brand.textMuted) }
        let improving = lowerIsBetter ? (diff < 0) : (diff > 0)
        return (improving ? "Improving" : "Declining", improving ? Brand.optimal : Brand.critical)
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(spacing: 0) {
            Text("SETTINGS")
                .font(.caption.weight(.semibold))
                .foregroundColor(Brand.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Connected devices
                Link(destination: URL(string: "https://vital-health-dashboard.vercel.app/settings/devices")!) {
                    settingsRow(icon: "applewatch.and.arrow.forward", title: "Connected Devices", trailing: "arrow.up.right")
                }

                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

                // Daily targets
                NavigationLink {
                    SettingsView()
                } label: {
                    settingsRow(icon: "target", title: "Daily Targets", trailing: "chevron.right")
                }

                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

                // Web dashboard
                Link(destination: URL(string: "https://vital-health-dashboard.vercel.app")!) {
                    settingsRow(icon: "globe", title: "Web Dashboard", trailing: "arrow.up.right")
                }

                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

                // Privacy
                Link(destination: URL(string: "https://vital-health-dashboard.vercel.app/privacy")!) {
                    settingsRow(icon: "hand.raised.fill", title: "Privacy Policy", trailing: "arrow.up.right")
                }

                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

                // Sign out
                Button {
                    showSignOutConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.body)
                            .foregroundColor(Brand.critical)
                            .frame(width: 32, height: 32)
                        Text("Sign Out")
                            .font(.subheadline)
                            .foregroundColor(Brand.critical)
                        Spacer()
                    }
                    .padding(14)
                }
            }
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func settingsRow(icon: String, title: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Brand.textSecondary)
                .frame(width: 32, height: 32)
            Text(title)
                .font(.subheadline)
                .foregroundColor(Brand.textPrimary)
            Spacer()
            Image(systemName: trailing)
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
        .padding(14)
    }

    // MARK: - Helpers

    private func formatDrawDate(_ dateStr: String) -> String? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: date)
    }

    // MARK: - Data

    private func loadData() async {
        do {
            async let profileResp: APIResponse<UserProfile> = apiService.get("/profile")
            async let targetsResp: APIResponse<UserTargets> = apiService.get("/targets")
            async let metricsResp: APIResponse<[DailyMetric]> = apiService.get("/metrics")
            async let labsResp: APIResponse<[LabResult]> = apiService.get("/labs")
            async let supplementsResp: APIResponse<[Supplement]> = apiService.get("/supplements")

            let (p, t, m, l, s) = try await (profileResp, targetsResp, metricsResp, labsResp, supplementsResp)
            profile = p.data
            targets = t.data
            metrics = m.data ?? []
            labs = l.data ?? []
            supplements = s.data ?? []
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

// MARK: - Flow Layout (for pills)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
