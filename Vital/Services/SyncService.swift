import Foundation

@MainActor
class SyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncLog: [SyncLogEntry] = []

    private let healthKitService: HealthKitService
    private let authService: AuthService

    private let lastSyncKey = "lastSyncDate"
    private let syncLogKey = "syncLog"

    init(healthKitService: HealthKitService, authService: AuthService) {
        self.healthKitService = healthKitService
        self.authService = authService
        loadState()
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let token = await authService.accessToken() else {
            addLogEntry(success: false, errorMessage: "Not signed in")
            return
        }

        let since = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -Config.defaultSyncLookbackDays, to: Date())!

        do {
            let metrics = try await healthKitService.queryMetrics(since: since)
            let workouts = try await healthKitService.queryWorkouts(since: since)

            if metrics.isEmpty && workouts.isEmpty {
                addLogEntry(metricsUpdated: 0, workoutsCreated: 0, success: true)
                lastSyncDate = Date()
                saveState()
                return
            }

            let payload = IngestPayload(data: IngestData(metrics: metrics, workouts: workouts))
            let response = try await postToIngest(payload: payload, token: token)

            if response.success, let summary = response.summary {
                addLogEntry(
                    metricsUpdated: summary.metrics.updated + summary.metrics.created,
                    workoutsCreated: summary.workouts.created,
                    success: true
                )
                lastSyncDate = Date()
                saveState()
            } else {
                addLogEntry(success: false, errorMessage: response.error ?? "Unknown error")
            }
        } catch {
            addLogEntry(success: false, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Private

    private func postToIngest(payload: IngestPayload, token: String) async throws -> IngestResponse {
        var request = URLRequest(url: Config.ingestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw SyncError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SyncError.serverError(statusCode: httpResponse.statusCode, body: body)
        }

        return try JSONDecoder().decode(IngestResponse.self, from: data)
    }

    private func addLogEntry(metricsUpdated: Int = 0, workoutsCreated: Int = 0, success: Bool, errorMessage: String? = nil) {
        let entry = SyncLogEntry(
            date: Date(),
            metricsUpdated: metricsUpdated,
            workoutsCreated: workoutsCreated,
            success: success,
            errorMessage: errorMessage
        )
        syncLog.insert(entry, at: 0)
        if syncLog.count > 20 { syncLog = Array(syncLog.prefix(20)) }
        saveState()
    }

    private func loadState() {
        if let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            lastSyncDate = timestamp
        }
        if let data = UserDefaults.standard.data(forKey: syncLogKey),
           let log = try? JSONDecoder().decode([SyncLogEntry].self, from: data) {
            syncLog = log
        }
    }

    private func saveState() {
        UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
        if let data = try? JSONEncoder().encode(syncLog) {
            UserDefaults.standard.set(data, forKey: syncLogKey)
        }
    }
}

enum SyncError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .unauthorized: return "Session expired. Please sign in again."
        case .serverError(let code, _): return "Server error (\(code))"
        }
    }
}
