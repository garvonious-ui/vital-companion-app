import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) var dismiss

    @State private var profile: UserProfile?
    @State private var targets: UserTargets?
    @State private var syncLog: [SyncLogEntry] = []
    @State private var showSignOutConfirm = false

    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0C).ignoresSafeArea()

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
                        .listRowBackground(Color(hex: 0x141418))
                    }
                } header: {
                    Text("Profile")
                        .foregroundColor(Color(hex: 0x606070))
                }

                // Targets section
                Section {
                    if let targets {
                        targetRow(label: "Calories", value: targets.calories.map { "\($0) kcal" } ?? "—", color: 0x00B4D8)
                        targetRow(label: "Protein", value: targets.protein.map { "\($0)g" } ?? "—", color: 0x00D68F)
                        targetRow(label: "Carbs", value: targets.carbs.map { "\($0)g" } ?? "—", color: 0xFFB547)
                        targetRow(label: "Fat", value: targets.fat.map { "\($0)g" } ?? "—", color: 0x8B5CF6)
                        targetRow(label: "Steps", value: targets.steps.map { "\($0)" } ?? "—", color: 0x00B4D8)
                        targetRow(label: "Exercise", value: targets.exerciseMinutes.map { "\($0) min" } ?? "—", color: 0x00D68F)
                    }
                } header: {
                    Text("Daily Targets")
                        .foregroundColor(Color(hex: 0x606070))
                } footer: {
                    Text("Edit targets on the web dashboard")
                        .foregroundColor(Color(hex: 0x606070))
                }

                // Sync section
                Section {
                    let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
                    HStack {
                        Text("Last Sync")
                            .foregroundColor(.white)
                        Spacer()
                        if let lastSync {
                            Text(lastSync, style: .relative)
                                .foregroundColor(Color(hex: 0x606070))
                            Text("ago")
                                .foregroundColor(Color(hex: 0x606070))
                        } else {
                            Text("Never")
                                .foregroundColor(Color(hex: 0x606070))
                        }
                    }
                    .listRowBackground(Color(hex: 0x141418))

                    HStack {
                        Text("Frequency")
                            .foregroundColor(.white)
                        Spacer()
                        Text("Hourly + on app open")
                            .foregroundColor(Color(hex: 0x606070))
                    }
                    .listRowBackground(Color(hex: 0x141418))

                    // Recent sync log
                    if !syncLog.isEmpty {
                        ForEach(syncLog.prefix(5)) { entry in
                            HStack {
                                Circle()
                                    .fill(entry.success ? Color(hex: 0x00D68F) : Color(hex: 0xFF4757))
                                    .frame(width: 6, height: 6)

                                if entry.success {
                                    Text("\(entry.metricsUpdated) metrics, \(entry.workoutsCreated) workouts")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                } else {
                                    Text(entry.errorMessage ?? "Failed")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: 0xFF4757))
                                }

                                Spacer()

                                Text(entry.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(Color(hex: 0x606070))
                            }
                            .listRowBackground(Color(hex: 0x141418))
                        }
                    }
                } header: {
                    Text("Sync")
                        .foregroundColor(Color(hex: 0x606070))
                }

                // About section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.white)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(Color(hex: 0x606070))
                            .monospacedDigit()
                    }
                    .listRowBackground(Color(hex: 0x141418))

                    Link(destination: URL(string: "https://vital-health-dashboard.vercel.app")!) {
                        HStack {
                            Text("Web Dashboard")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(Color(hex: 0x00B4D8))
                        }
                    }
                    .listRowBackground(Color(hex: 0x141418))

                    Link(destination: URL(string: "https://vital-health-dashboard.vercel.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(Color(hex: 0x00B4D8))
                        }
                    }
                    .listRowBackground(Color(hex: 0x141418))
                } header: {
                    Text("About")
                        .foregroundColor(Color(hex: 0x606070))
                }

                // Sign out
                Section {
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .foregroundColor(Color(hex: 0xFF4757))
                            Spacer()
                        }
                    }
                    .listRowBackground(Color(hex: 0x141418))
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
    }

    // MARK: - Row Helpers

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color(hex: 0x00B4D8))
                .frame(width: 20)

            Text(label)
                .foregroundColor(Color(hex: 0xA0A0B0))

            Spacer()

            Text(value)
                .foregroundColor(.white)
        }
        .listRowBackground(Color(hex: 0x141418))
    }

    private func targetRow(label: String, value: String, color: UInt) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 8, height: 8)

            Text(label)
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .monospacedDigit()
                .foregroundColor(Color(hex: 0xA0A0B0))
        }
        .listRowBackground(Color(hex: 0x141418))
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
