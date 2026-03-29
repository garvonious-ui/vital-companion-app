import SwiftUI

struct MoreView: View {
    @EnvironmentObject var apiService: APIService

    @State private var profile: UserProfile?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A0A0C).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Profile header
                        profileCard

                        // Navigation items
                        navCard(
                            icon: "pill.fill",
                            iconColor: 0x00D68F,
                            title: "Supplements",
                            subtitle: "Your active stack"
                        ) {
                            SupplementsView()
                        }

                        navCard(
                            icon: "bubble.left.and.bubble.right.fill",
                            iconColor: 0x8B5CF6,
                            title: "AI Health Chat",
                            subtitle: "Ask about your health data"
                        ) {
                            ChatView()
                        }

                        // Sync status card
                        syncStatusCard

                        // Settings + links
                        settingsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadProfile()
            }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x00B4D8), Color(hex: 0x8B5CF6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text(initials)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.name ?? profile?.email ?? "Loading...")
                    .font(.headline)
                    .foregroundColor(.white)

                if let email = profile?.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(Color(hex: 0x606070))
                }

                if let goal = profile?.goal, !goal.isEmpty {
                    Text(goal)
                        .font(.caption)
                        .foregroundColor(Color(hex: 0x00B4D8))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(hex: 0x141418))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var initials: String {
        if let name = profile?.name {
            let parts = name.split(separator: " ")
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.count > 1 ? parts.last!.prefix(1) : ""
            return "\(first)\(last)".uppercased()
        }
        return profile?.email?.prefix(1).uppercased() ?? "?"
    }

    // MARK: - Navigation Card

    private func navCard<Destination: View>(icon: String, iconColor: UInt, title: String, subtitle: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(Color(hex: iconColor))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: iconColor).opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color(hex: 0x606070))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(hex: 0x606070))
            }
            .padding(14)
            .background(Color(hex: 0x141418))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Sync Status Card

    private var syncStatusCard: some View {
        let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date

        return HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.body)
                .foregroundColor(Color(hex: 0x00B4D8))
                .frame(width: 36, height: 36)
                .background(Color(hex: 0x00B4D8).opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sync Status")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                if let lastSync {
                    Text("Last synced \(lastSync, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(Color(hex: 0x606070))
                } else {
                    Text("Not synced yet")
                        .font(.caption)
                        .foregroundColor(Color(hex: 0x606070))
                }
            }

            Spacer()

            Circle()
                .fill(lastSync != nil ? Color(hex: 0x00D68F) : Color(hex: 0x606070))
                .frame(width: 8, height: 8)
        }
        .padding(14)
        .background(Color(hex: 0x141418))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SettingsView()
            } label: {
                settingsRow(icon: "gearshape.fill", title: "Settings")
            }

            Divider().background(Color.white.opacity(0.06))

            Link(destination: URL(string: "https://vital-health-dashboard.vercel.app")!) {
                settingsRow(icon: "globe", title: "Web Dashboard")
            }

            Divider().background(Color.white.opacity(0.06))

            Link(destination: URL(string: "https://vital-health-dashboard.vercel.app/privacy")!) {
                settingsRow(icon: "hand.raised.fill", title: "Privacy Policy")
            }
        }
        .background(Color(hex: 0x141418))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func settingsRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color(hex: 0xA0A0B0))
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Color(hex: 0x606070))
        }
        .padding(14)
    }

    // MARK: - Data

    private func loadProfile() async {
        do {
            let resp: APIResponse<UserProfile> = try await apiService.get("/profile")
            profile = resp.data
        } catch {
            // Non-critical, just show placeholder
        }
    }
}
