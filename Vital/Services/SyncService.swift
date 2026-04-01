import Foundation
import Observation

@MainActor
@Observable class SyncService {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncLog: [SyncLogEntry] = []

    private let healthKitService: HealthKitService
    private let authService: AuthService

    private let lastSyncKey = "lastSyncDate"
    private let syncLogKey = "syncLog"

    private let maxRetries = 3
    private let baseDelay: TimeInterval = 2 // 2s, 4s, 8s

    init(healthKitService: HealthKitService, authService: AuthService) {
        self.healthKitService = healthKitService
        self.authService = authService
        loadState()
    }

    func sync() async {
        guard !isSyncing else {
            print("[Sync] Already syncing, skipping")
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        guard let token = await authService.accessToken() else {
            print("[Sync] No token — not signed in")
            addLogEntry(success: false, errorMessage: "Not signed in")
            return
        }

        // Always query from start of day so cumulative metrics (steps, calories, exercise)
        // contain full-day totals. Use lastSyncDate only to determine how far back to go,
        // but round down to midnight so we never send partial-day data.
        let lookback = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -Config.defaultSyncLookbackDays, to: Date())!
        let since = Calendar.current.startOfDay(for: lookback)
        print("[Sync] Starting sync from \(since), lastSyncDate: \(String(describing: lastSyncDate))")

        do {
            let metrics = try await healthKitService.queryMetrics(since: since)
            let workouts = try await healthKitService.queryWorkouts(since: since)
            print("[Sync] HealthKit returned \(metrics.count) metrics, \(workouts.count) workouts")

            if metrics.isEmpty && workouts.isEmpty {
                addLogEntry(metricsUpdated: 0, workoutsCreated: 0, success: true)
                lastSyncDate = Date()
                saveState()
                return
            }

            let payload = IngestPayload(data: IngestData(metrics: metrics, workouts: workouts))
            let response = try await postWithRetry(payload: payload, token: token)

            if response.success, let summary = response.summary {
                print("[Sync] Success — metrics: \(summary.metrics.updated + summary.metrics.created), workouts: \(summary.workouts.created)")
                addLogEntry(
                    metricsUpdated: summary.metrics.updated + summary.metrics.created,
                    workoutsCreated: summary.workouts.created,
                    success: true
                )
                lastSyncDate = Date()
                saveState()
            } else {
                print("[Sync] API error: \(response.error ?? "Unknown")")
                addLogEntry(success: false, errorMessage: response.error ?? "Unknown error")
            }
        } catch let error as SyncError {
            print("[Sync] SyncError: \(error.errorDescription ?? "?")")
            addLogEntry(success: false, errorMessage: error.errorDescription)
        } catch let error as URLError {
            let message: String
            switch error.code {
            case .notConnectedToInternet:
                message = "No internet connection"
            case .timedOut:
                message = "Request timed out"
            case .networkConnectionLost:
                message = "Connection lost during sync"
            default:
                message = "Network error: \(error.localizedDescription)"
            }
            addLogEntry(success: false, errorMessage: message)
        } catch {
            addLogEntry(success: false, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Retry Logic

    private func postWithRetry(payload: IngestPayload, token: String) async throws -> IngestResponse {
        var currentToken = token
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await postToIngest(payload: payload, token: currentToken)
            } catch SyncError.unauthorized {
                // Try refreshing the session once
                if attempt == 0, await authService.refreshSession(),
                   let newToken = await authService.accessToken() {
                    currentToken = newToken
                    continue
                }
                throw SyncError.unauthorized
            } catch let error as URLError {
                lastError = error
                // Don't retry on non-transient network errors
                if error.code == .notConnectedToInternet || error.code == .cancelled {
                    throw error
                }
                if attempt < maxRetries - 1 {
                    let delay = baseDelay * pow(2, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch let error as SyncError {
                // Don't retry client errors (4xx except 401)
                if case .serverError(let code, _) = error, code >= 500 {
                    lastError = error
                    if attempt < maxRetries - 1 {
                        let delay = baseDelay * pow(2, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                } else {
                    throw error
                }
            }
        }

        throw lastError ?? SyncError.invalidResponse
    }

    // MARK: - Network

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

    // MARK: - Log

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

    func resetAndSync() async {
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        await sync()
    }

    // MARK: - Persistence

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
