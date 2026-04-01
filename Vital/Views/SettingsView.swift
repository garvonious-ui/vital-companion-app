import SwiftUI
import SafariServices

struct SettingsView: View {
    @Environment(AuthService.self) var authService
    @Environment(APIService.self) var apiService
    @Environment(SyncService.self) var syncService
    @Environment(\.dismiss) var dismiss

    @State private var profile: UserProfile?
    @State private var targets: UserTargets?
    @State private var syncLog: [SyncLogEntry] = []
    @State private var showSignOutConfirm = false
    @State private var safariURL: URL?

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            List {
                // Profile section
                Section {
                    if let profile {
                        profileRow(icon: "person.fill", label: "Name", value: profile.name ?? "—")
                        profileRow(icon: "envelope.fill", label: "Email", value: profile.email ?? "—")
                        if let goal = profile.goal, !goal.isEmpty {
                            profileRow(icon: "target", label: "Goal", value: goal)
                        }
                        if let weight = profile.weight {
                            profileRow(icon: "scalemass.fill", label: "Weight", value: "\(Int(weight)) lbs")
                        }
                    } else {
                        HStack {
                            Spacer()
                            ProgressView().tint(.white)
                            Spacer()
                        }
                        .listRowBackground(Brand.card)
                    }
                } header: {
                    Text("Profile")
                        .foregroundColor(Brand.textMuted)
                }

                // Targets section
                Section {
                    if let targets {
                        targetRow(label: "Calories", value: targets.calories.map { "\($0) kcal" } ?? "—", color: Brand.accent)
                        targetRow(label: "Protein", value: targets.protein.map { "\($0)g" } ?? "—", color: Brand.optimal)
                        targetRow(label: "Carbs", value: targets.carbs.map { "\($0)g" } ?? "—", color: Brand.warning)
                        targetRow(label: "Fat", value: targets.fat.map { "\($0)g" } ?? "—", color: Brand.secondary)
                        targetRow(label: "Steps", value: targets.steps.map { "\($0)" } ?? "—", color: Brand.accent)
                        targetRow(label: "Exercise", value: targets.exerciseMinutes.map { "\($0) min" } ?? "—", color: Brand.optimal)
                    }
                } header: {
                    Text("Daily Targets")
                        .foregroundColor(Brand.textMuted)
                } footer: {
                    Text("Edit targets on the web dashboard")
                        .foregroundColor(Brand.textMuted)
                }

                // Sync section
                Section {
                    let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
                    HStack {
                        Text("Last Sync")
                            .foregroundColor(Brand.textPrimary)
                        Spacer()
                        if let lastSync {
                            Text(lastSync, style: .relative)
                                .foregroundColor(Brand.textMuted)
                            Text("ago")
                                .foregroundColor(Brand.textMuted)
                        } else {
                            Text("Never")
                                .foregroundColor(Brand.textMuted)
                        }
                    }
                    .listRowBackground(Brand.card)

                    HStack {
                        Text("Frequency")
                            .foregroundColor(Brand.textPrimary)
                        Spacer()
                        Text("Hourly + on app open")
                            .foregroundColor(Brand.textMuted)
                    }
                    .listRowBackground(Brand.card)

                    // Recent sync log
                    if !syncLog.isEmpty {
                        ForEach(syncLog.prefix(5)) { entry in
                            HStack {
                                Circle()
                                    .fill(entry.success ? Brand.optimal : Brand.critical)
                                    .frame(width: 6, height: 6)

                                if entry.success {
                                    Text("\(entry.metricsUpdated) metrics, \(entry.workoutsCreated) workouts")
                                        .font(.caption)
                                        .foregroundColor(Brand.textPrimary)
                                } else {
                                    Text(entry.errorMessage ?? "Failed")
                                        .font(.caption)
                                        .foregroundColor(Brand.critical)
                                }

                                Spacer()

                                Text(entry.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(Brand.textMuted)
                            }
                            .listRowBackground(Brand.card)
                        }
                    }
                } header: {
                    Text("Sync")
                        .foregroundColor(Brand.textMuted)
                }

                // Troubleshooting section
                Section {
                    Button {
                        Task {
                            await syncService.resetAndSync()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Brand.accent)
                            Text("Force Full Sync")
                                .foregroundColor(Brand.textPrimary)
                            Spacer()
                            Text("7 days")
                                .font(.caption)
                                .foregroundColor(Brand.textMuted)
                        }
                    }
                    .disabled(syncService.isSyncing)
                    .listRowBackground(Brand.card)
                } header: {
                    Text("Troubleshooting")
                        .foregroundColor(Brand.textMuted)
                }

                // About section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(Brand.textPrimary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(Brand.textMuted)
                            .monospacedDigit()
                    }
                    .listRowBackground(Brand.card)

                    safariRow("Web Dashboard", url: "https://vital-health-dashboard.vercel.app")
                    safariRow("Privacy Policy", url: "https://vital-health-dashboard.vercel.app/privacy")
                    safariRow("Support", url: "mailto:lou@loucesario.com")
                } header: {
                    Text("About")
                        .foregroundColor(Brand.textMuted)
                }

                // Sign out
                Section {
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .foregroundColor(Brand.critical)
                            Spacer()
                        }
                    }
                    .listRowBackground(Brand.card)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await authService.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: Binding(
            get: { safariURL != nil },
            set: { if !$0 { safariURL = nil } }
        )) {
            if let url = safariURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Row Helpers

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Brand.accent)
                .frame(width: 20)

            Text(label)
                .foregroundColor(Brand.textSecondary)

            Spacer()

            Text(value)
                .foregroundColor(Brand.textPrimary)
        }
        .listRowBackground(Brand.card)
    }

    private func targetRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .foregroundColor(Brand.textPrimary)

            Spacer()

            Text(value)
                .monospacedDigit()
                .foregroundColor(Brand.textSecondary)
        }
        .listRowBackground(Brand.card)
    }

    private func safariRow(_ label: String, url: String) -> some View {
        Button {
            if let parsed = URL(string: url) {
                if url.hasPrefix("mailto:") {
                    UIApplication.shared.open(parsed)
                } else {
                    safariURL = parsed
                }
            }
        } label: {
            HStack {
                Text(label)
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Image(systemName: url.hasPrefix("mailto:") ? "envelope" : "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(Brand.accent)
            }
        }
        .listRowBackground(Brand.card)
    }

    // MARK: - Data

    private func loadData() async {
        do {
            async let profileResp: APIResponse<UserProfile> = apiService.get("/profile")
            async let targetsResp: APIResponse<UserTargets> = apiService.get("/targets")

            let (p, t) = try await (profileResp, targetsResp)
            profile = p.data
            targets = t.data
        } catch {
            // Non-critical
        }

        // Load sync log from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "syncLog"),
           let log = try? JSONDecoder().decode([SyncLogEntry].self, from: data) {
            syncLog = log
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = UIColor(Brand.bg)
        vc.preferredControlTintColor = UIColor(Brand.accent)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
