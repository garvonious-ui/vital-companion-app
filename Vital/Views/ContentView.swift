import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) var authService
    @Environment(HealthKitService.self) var healthKitService
    @Environment(APIService.self) var apiService

    @State private var hasProfile = true // assume true until checked
    @State private var profileChecked = false
    @State private var onboardingComplete = false

    var body: some View {
        Group {
            if authService.isLoading {
                ZStack {
                    Brand.bg.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            } else if !authService.isSignedIn {
                LoginView()
            } else if !healthKitService.isAuthorized {
                PermissionsView()
            } else if !profileChecked {
                ZStack {
                    Brand.bg.ignoresSafeArea()
                    ProgressView().tint(.white)
                }
                .task { await checkProfile() }
            } else if !hasProfile && !onboardingComplete {
                OnboardingView(isComplete: $onboardingComplete)
            } else {
                MainTabView()
            }
        }
        .onChange(of: authService.isSignedIn) { _, signedIn in
            if signedIn {
                profileChecked = false
                hasProfile = true
            }
        }
    }

    private func checkProfile() async {
        do {
            let resp: APIResponse<UserProfile> = try await apiService.get("/profile")
            hasProfile = resp.data?.displayName != nil
        } catch {
            hasProfile = false
        }
        profileChecked = true
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AuthService.self) var authService
    @Environment(HealthKitService.self) var healthKitService
    @Environment(SyncService.self) var syncService
    @Environment(APIService.self) var apiService
    @Environment(NetworkMonitor.self) var networkMonitor

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var hasLaunched = false

    var body: some View {
        VStack(spacing: 0) {
            // Offline banner
            if !networkMonitor.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text("No internet connection")
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Brand.critical.opacity(0.9))
                .foregroundColor(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
            }

        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("Today")
                }
                .tag(0)

            ActivityView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Activity")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(2)
        }
        .tint(Brand.accent)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.light()
        }
        .onAppear {
            // Style the tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Brand.bg)
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Brand.textMuted)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Brand.textMuted)]
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .task {
            // Enable HealthKit background delivery + initial sync on launch
            healthKitService.enableBackgroundDelivery()
            await syncService.sync()
            hasLaunched = true
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && hasLaunched {
                Task { await syncService.sync() }
            }
        }
        } // close VStack
    }
}

// Color(hex:) extension is in BrandColors.swift
