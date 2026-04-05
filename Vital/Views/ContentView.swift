import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) var authService
    @Environment(HealthKitService.self) var healthKitService
    @Environment(APIService.self) var apiService

    @State private var hasProfile = true // assume true until checked
    @State private var profileChecked = false
    @State private var onboardingComplete = false
    @State private var deviceType: DeviceType?

    private let deviceTypeKey = "selectedDeviceType"

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
            } else if deviceType == nil {
                DeviceSelectionView { selected in
                    deviceType = selected
                    UserDefaults.standard.set(selected.rawValue, forKey: deviceTypeKey)
                    // If Apple Watch was selected, HealthKit is now authorized
                    // For other types, skip HealthKit gate
                }
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
                // Load saved device type
                if let saved = UserDefaults.standard.string(forKey: deviceTypeKey),
                   let type = DeviceType(rawValue: saved) {
                    deviceType = type
                } else {
                    deviceType = nil
                }
            } else {
                deviceType = nil
            }
        }
        .onAppear {
            // Restore device type for returning users
            if authService.isSignedIn {
                if let saved = UserDefaults.standard.string(forKey: deviceTypeKey),
                   let type = DeviceType(rawValue: saved) {
                    deviceType = type
                } else if healthKitService.isAuthorized {
                    // Existing user who already passed HealthKit gate
                    deviceType = .appleWatch
                    UserDefaults.standard.set(DeviceType.appleWatch.rawValue, forKey: deviceTypeKey)
                }
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
            let savedDevice = UserDefaults.standard.string(forKey: "selectedDeviceType")
                .flatMap { DeviceType(rawValue: $0) } ?? .appleWatch
            if savedDevice.shouldSyncHealthKit {
                healthKitService.enableBackgroundDelivery()
                await syncService.sync()
            }
            if savedDevice == .oura {
                await triggerOuraSync()
            }
            hasLaunched = true
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && hasLaunched {
                Task {
                    _ = await authService.refreshSession()
                    let savedDevice = UserDefaults.standard.string(forKey: "selectedDeviceType")
                        .flatMap { DeviceType(rawValue: $0) } ?? .appleWatch
                    if savedDevice.shouldSyncHealthKit {
                        await syncService.sync()
                    }
                    if savedDevice == .oura {
                        await triggerOuraSync()
                    }
                }
            }
        }
        } // close VStack
    }
}

extension MainTabView {
    func triggerOuraSync() async {
        do {
            let _: SuccessResponse = try await apiService.postRaw("/devices/oura/sync", jsonData: Data("{}".utf8))
            print("[OuraSync] Synced successfully")
        } catch {
            print("[OuraSync] Failed: \(error)")
        }
    }
}

// Color(hex:) extension is in BrandColors.swift
