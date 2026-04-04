import SwiftUI

struct MoreView: View {
    @Environment(APIService.self) var apiService

    @State private var profile: UserProfile?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Profile header
                        profileCard

                        // Navigation items
                        navCard(
                            icon: "pill.fill",
                            iconColor: Brand.optimal,
                            title: "Supplements",
                            subtitle: "Your active stack"
                        ) {
                            SupplementsView()
                        }

                        navCard(
                            icon: "cross.case.fill",
                            iconColor: Brand.accent,
                            title: "Lab Results",
                            subtitle: "Blood work & biomarkers"
                        ) {
                            LabsView()
                        }

                        navCard(
                            icon: "bubble.left.and.bubble.right.fill",
                            iconColor: Brand.secondary,
                            title: "AI Health Chat",
                            subtitle: "Ask about your health data"
                        ) {
                            ChatHistoryView()
                        }

                        // Connect devices
                        connectDevicesCard

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
                            colors: [Brand.accent, Brand.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text(initials)
                    .font(.headline.weight(.bold))
                    .foregroundColor(Brand.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.name ?? profile?.email ?? "Loading...")
                    .font(.headline)
                    .foregroundColor(Brand.textPrimary)

                if let email = profile?.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }

                if let goal = profile?.goal, !goal.isEmpty {
                    Text(goal)
                        .font(.caption)
                        .foregroundColor(Brand.accent)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Brand.card)
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

    private func navCard<Destination: View>(icon: String, iconColor: Color, title: String, subtitle: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Brand.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }
            .padding(14)
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Connect Devices Card

    private var connectDevicesCard: some View {
        Link(destination: URL(string: "https://vital-health-dashboard.vercel.app/settings/devices")!) {
            HStack(spacing: 14) {
                Image(systemName: "applewatch.and.arrow.forward")
                    .font(.body)
                    .foregroundColor(Brand.secondary)
                    .frame(width: 36, height: 36)
                    .background(Brand.secondary.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Devices")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Brand.textPrimary)
                    Text("Oura Ring, Whoop & more")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }
            .padding(14)
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Sync Status Card

    private var syncStatusCard: some View {
        let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date

        return HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.body)
                .foregroundColor(Brand.accent)
                .frame(width: 36, height: 36)
                .background(Brand.accent.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sync Status")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textPrimary)

                if let lastSync {
                    Text("Last synced \(lastSync, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                } else {
                    Text("Not synced yet")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }
            }

            Spacer()

            Circle()
                .fill(lastSync != nil ? Brand.optimal : Brand.textMuted)
                .frame(width: 8, height: 8)
        }
        .padding(14)
        .background(Brand.card)
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
        .background(Brand.card)
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
                .foregroundColor(Brand.textSecondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(Brand.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
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

// MARK: - Press Scale Button Style

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
