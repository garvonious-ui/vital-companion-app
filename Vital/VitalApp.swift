import SwiftUI
import BackgroundTasks

@main
struct VitalApp: App {
    @State private var authService: AuthService
    @State private var healthKitService: HealthKitService
    @State private var syncService: SyncService
    @State private var apiService: APIService
    @State private var networkMonitor: NetworkMonitor
    @State private var chatHistory: ChatHistoryManager

    init() {
        let auth = AuthService()
        let healthKit = HealthKitService()
        let sync = SyncService(healthKitService: healthKit, authService: auth)
        let api = APIService(authService: auth)
        let network = NetworkMonitor()
        let chat = ChatHistoryManager()

        self.authService = auth
        self.healthKitService = healthKit
        self.syncService = sync
        self.apiService = api
        self.networkMonitor = network
        self.chatHistory = chat

        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(healthKitService)
                .environment(syncService)
                .environment(apiService)
                .environment(networkMonitor)
                .environment(chatHistory)
                .preferredColorScheme(.dark)
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Config.backgroundTaskIdentifier,
            using: nil
        ) { [self] task in
            guard let bgTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                await self.syncService.sync()
                bgTask.setTaskCompleted(success: true)
                self.scheduleNextSync()
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
