import Foundation

struct MetricSample: Codable, Sendable {
    let date: String
    let qty: Double
}

struct MetricPayload: Codable, Sendable {
    let name: String
    let data: [MetricSample]
}

struct WorkoutPayload: Codable, Sendable {
    let name: String
    let start: String
    let end: String
    let duration: Double
    let activeEnergyBurned: QuantityValue?
    let avgHeartRate: QuantityValue?
    let maxHeartRate: QuantityValue?
}

struct QuantityValue: Codable, Sendable {
    let qty: Double
}

struct IngestPayload: Codable, Sendable {
    let data: IngestData
}

struct IngestData: Codable, Sendable {
    let metrics: [MetricPayload]
    let workouts: [WorkoutPayload]
}

struct IngestResponse: Codable, Sendable {
    let success: Bool
    let summary: IngestSummary?
    let error: String?
}

struct IngestSummary: Codable, Sendable {
    let metrics: MetricsSummary
    let workouts: WorkoutsSummary
}

struct MetricsSummary: Codable, Sendable {
    let created: Int
    let updated: Int
    let skipped: Int
}

struct WorkoutsSummary: Codable, Sendable {
    let created: Int
    let skipped: Int
}

struct SyncLogEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let metricsUpdated: Int
    let workoutsCreated: Int
    let success: Bool
    let errorMessage: String?

    init(date: Date, metricsUpdated: Int, workoutsCreated: Int, success: Bool, errorMessage: String? = nil) {
        self.id = UUID()
        self.date = date
        self.metricsUpdated = metricsUpdated
        self.workoutsCreated = workoutsCreated
        self.success = success
        self.errorMessage = errorMessage
    }
}
