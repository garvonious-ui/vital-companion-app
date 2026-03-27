import SwiftUI
import BackgroundTasks

@main
struct VitalApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var healthKitService = HealthKitService()

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(healthKitService)
                .preferredColorScheme(.dark)
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Config.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let bgTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                let syncService = SyncService(healthKitService: healthKitService, authService: authService)
                await syncService.sync()
                bgTask.setTaskCompleted(success: true)
                scheduleNextSync()
            }
        }
    }

    private func scheduleNextSync() {
        let request = BGAppRefreshTaskRequest(identifier: Config.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background sync: \(error)")
        }
    }
}
