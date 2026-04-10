import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) var authService
    @Environment(HealthKitService.self) var healthKitService
    @Environment(APIService.self) var apiService

    @State private var hasProfile = true // assume true until checked
    @State private var profileChecked = false
    @State private var onboardingComplete = false
    // Seeded from UserDefaults synchronously at view-creation time so existing
    // users never render with `deviceType == nil` during the brief window
    // between `isSignedIn` flipping true and the `onChange` handler running.
    // That window used to cause `contentLayer` to evaluate to DeviceSelectionView
    // and flicker through while the splash was fading out.
    @State private var deviceType: DeviceType? = {
        if let saved = UserDefaults.standard.string(forKey: "selectedDeviceType"),
           let type = DeviceType(rawValue: saved) {
            return type
        }
        return nil
    }()

    private let deviceTypeKey = "selectedDeviceType"

    /// True whenever we're in a "pre-MainTabView" async state where the user
    /// should see the splash: either auth is still resolving, or auth finished
    /// and we're waiting on the one-shot profile-check round trip.
    private var showSplash: Bool {
        authService.isLoading
            || (authService.isSignedIn && deviceType != nil && !profileChecked)
    }

    var body: some View {
        ZStack {
            // Real content always renders underneath. While `showSplash` is
            // true the splash covers it; when splash fades out the content is
            // already fully mounted so the handoff is seamless.
            contentLayer

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: showSplash)
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

    /// The actual screen behind the splash. Switches based on auth / device /
    /// profile state. The splash overlay handles visibility during the async
    /// startup chain — this layer is free to switch cleanly underneath.
    @ViewBuilder
    private var contentLayer: some View {
        if !authService.isSignedIn {
            LoginView()
        } else if deviceType == nil {
            DeviceSelectionView { selected in
                deviceType = selected
                UserDefaults.standard.set(selected.rawValue, forKey: deviceTypeKey)
            }
        } else if !profileChecked {
            // Invisible placeholder — splash is overlaid on top. The `.task`
            // fires once when this branch appears to kick off the profile
            // round trip. Using `Color.clear` here keeps the task wired to the
            // branch's lifecycle without mounting any competing UI.
            Color.clear
                .task { await checkProfile() }
        } else if !hasProfile && !onboardingComplete {
            OnboardingView(isComplete: $onboardingComplete)
        } else {
            MainTabView()
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
    @Environment(RefreshCoordinator.self) var refreshCoordinator

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var hasLaunched = false
    @State private var lastForegroundRefresh: Date = .distantPast

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
            // Initial launch: kick off background sync concurrently, don't block
            // the tabs' own data loads. The tabs fire their own `.task` in parallel
            // and will re-load when the coordinator bumps after sync finishes.
            await runBackgroundSync()
            hasLaunched = true
            lastForegroundRefresh = Date()
            refreshCoordinator.requestRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, hasLaunched else { return }
            // Foreground debounce: ignore rapid scenePhase flips (lock screen,
            // notification center, app switcher). 10s cooldown.
            if Date().timeIntervalSince(lastForegroundRefresh) < 10 { return }
            lastForegroundRefresh = Date()
            Task {
                _ = await authService.refreshSession()
                await runBackgroundSync()
                refreshCoordinator.requestRefresh()
            }
        }
        } // close VStack
    }

    /// Runs the device-appropriate sync (HealthKit OR Oura — a user is exactly
    /// one device type, so these are mutually exclusive). Errors are logged but
    /// swallowed so a sync failure never blocks the UI from refreshing.
    private func runBackgroundSync() async {
        let savedDevice = UserDefaults.standard.string(forKey: "selectedDeviceType")
            .flatMap { DeviceType(rawValue: $0) } ?? .appleWatch
        if savedDevice.shouldSyncHealthKit {
            healthKitService.enableBackgroundDelivery()
            await syncService.sync()
        } else if savedDevice == .oura {
            await triggerOuraSync()
        }
    }
}

extension MainTabView {
    /// Last successful Oura sync timestamp. Static so it survives SwiftUI view
    /// re-creation (MainTabView can be rebuilt on scene transitions).
    private static let ouraSyncCooldown: TimeInterval = 5 * 60
    private static var lastOuraSyncAt: Date = .distantPast

    func triggerOuraSync() async {
        // Backend-side Oura sync is expensive — it hits the Oura API on every
        // call. 5-minute cooldown prevents rapid foreground flips from piling
        // up redundant syncs.
        if Date().timeIntervalSince(Self.lastOuraSyncAt) < Self.ouraSyncCooldown {
            print("[OuraSync] Skipped (within cooldown)")
            return
        }
        do {
            let _: SuccessResponse = try await apiService.postRaw("/devices/oura/sync", jsonData: Data("{}".utf8))
            Self.lastOuraSyncAt = Date()
            print("[OuraSync] Synced successfully")
        } catch {
            print("[OuraSync] Failed: \(error)")
        }
    }
}

// Color(hex:) extension is in BrandColors.swift
