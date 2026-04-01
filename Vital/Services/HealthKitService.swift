import Foundation
import HealthKit
import Observation

@MainActor
@Observable class HealthKitService {
    let healthStore = HKHealthStore()
    var isAuthorized = false

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.vo2Max),
            HKQuantityType(.bodyMass),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate),
            HKObjectType.workoutType(),
        ]
        types.insert(HKCategoryType(.sleepAnalysis))
        return types
    }()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    func enableBackgroundDelivery() {
        let quantityTypes: [HKQuantityType] = [
            .init(.heartRateVariabilitySDNN),
            .init(.restingHeartRate),
            .init(.stepCount),
            .init(.appleExerciseTime),
            .init(.activeEnergyBurned),
            .init(.vo2Max),
            .init(.bodyMass),
            .init(.distanceWalkingRunning),
            .init(.oxygenSaturation),
            .init(.respiratoryRate),
        ]
        for type in quantityTypes {
            healthStore.enableBackgroundDelivery(for: type, frequency: .hourly) { _, error in
                if let error { print("Background delivery failed for \(type): \(error)") }
            }
        }
        healthStore.enableBackgroundDelivery(for: HKCategoryType(.sleepAnalysis), frequency: .hourly) { _, error in
            if let error { print("Background delivery failed for sleep: \(error)") }
        }
    }

    func queryMetrics(since startDate: Date) async throws -> [MetricPayload] {
        var payloads: [MetricPayload] = []

        // Cumulative metrics — use HKStatisticsQuery to deduplicate across iPhone + Watch
        let cumulativeMetrics: [(HKQuantityType, String, HKUnit)] = [
            (.init(.stepCount), "step_count", .count()),
            (.init(.appleExerciseTime), "exercise_time", .minute()),
            (.init(.activeEnergyBurned), "active_energy_burned", .kilocalorie()),
            (.init(.distanceWalkingRunning), "distance_walking_running", .mile()),
        ]

        for (type, name, unit) in cumulativeMetrics {
            let dailySums = await queryDailySum(type: type, unit: unit, since: startDate)
            if !dailySums.isEmpty {
                payloads.append(MetricPayload(name: name, data: dailySums))
            }
        }

        // Discrete metrics — use sample query (averaging happens on backend)
        let discreteMetrics: [(HKQuantityType, String, HKUnit)] = [
            (.init(.heartRateVariabilitySDNN), "heart_rate_variability", .secondUnit(with: .milli)),
            (.init(.restingHeartRate), "resting_heart_rate", HKUnit.count().unitDivided(by: .minute())),
            (.init(.vo2Max), "vo2_max", HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))),
            (.init(.bodyMass), "body_mass", .pound()),
            (.init(.oxygenSaturation), "oxygen_saturation", .percent()),
            (.init(.respiratoryRate), "respiratory_rate", HKUnit.count().unitDivided(by: .minute())),
        ]

        // Query discrete metrics from 1 day earlier — overnight metrics like resting HR
        // are written with a startDate from the previous night
        let discreteSince = Calendar.current.date(byAdding: .day, value: -1, to: startDate)!
        let todayDateStr = formatDate(Date()) // used to attribute overnight metrics to today
        for (type, name, unit) in discreteMetrics {
            let samples = try await querySamples(type: type, since: discreteSince)
            print("[HealthKit] \(name): \(samples.count) samples (since \(discreteSince))")
            if !samples.isEmpty {
                let metricSamples: [MetricSample]
                if name == "resting_heart_rate" {
                    // Resting HR is computed from overnight data — attribute the most recent
                    // sample to today so the backend upserts it into today's row
                    let latest = samples.first! // sorted descending
                    metricSamples = [MetricSample(
                        date: todayDateStr,
                        qty: latest.quantity.doubleValue(for: unit)
                    )]
                } else {
                    metricSamples = samples.map { sample in
                        MetricSample(
                            date: formatDate(sample.startDate),
                            qty: sample.quantity.doubleValue(for: unit)
                        )
                    }
                }
                payloads.append(MetricPayload(name: name, data: metricSamples))
            }
        }

        // Sleep
        let sleepSamples = try await querySleepSamples(since: startDate)
        if !sleepSamples.isEmpty {
            let sleepMetrics = sleepSamples.map { sample in
                let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
                return MetricSample(date: formatDate(sample.startDate), qty: minutes)
            }
            payloads.append(MetricPayload(name: "sleep_analysis", data: sleepMetrics))
        }

        return payloads
    }

    func queryWorkouts(since startDate: Date) async throws -> [WorkoutPayload] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                let payloads = workouts.map { workout -> WorkoutPayload in
                    let name = workout.workoutActivityType.displayName
                    let duration = workout.duration
                    let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    let avgHR = self.averageHeartRate(for: workout)
                    let maxHR = self.maxHeartRate(for: workout)

                    return WorkoutPayload(
                        name: name,
                        start: self.formatDate(workout.startDate),
                        end: self.formatDate(workout.endDate),
                        duration: duration,
                        activeEnergyBurned: energy.map { QuantityValue(qty: $0) },
                        avgHeartRate: avgHR.map { QuantityValue(qty: $0) },
                        maxHeartRate: maxHR.map { QuantityValue(qty: $0) }
                    )
                }
                continuation.resume(returning: payloads)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Private

    private func queryDailySum(type: HKQuantityType, unit: HKUnit, since startDate: Date) async -> [MetricSample] {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { (continuation: CheckedContinuation<[MetricSample], Never>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, _ in
                var results: [MetricSample] = []
                collection?.enumerateStatistics(from: anchorDate, to: Date()) { statistics, _ in
                    if let sum = statistics.sumQuantity()?.doubleValue(for: unit), sum > 0 {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                        formatter.timeZone = TimeZone(identifier: "America/New_York")
                        results.append(MetricSample(date: formatter.string(from: statistics.startDate), qty: sum))
                    }
                }
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
    }

    private func querySamples(type: HKQuantityType, since startDate: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 500,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func querySleepSamples(since startDate: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: 200,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sleepSamples = (samples as? [HKCategorySample])?.filter { sample in
                    // Only count "asleep" categories, not "inBed"
                    sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue
                } ?? []
                continuation.resume(returning: sleepSamples)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sleep Detail Queries

    struct SleepStageData: Sendable {
        let rem: TimeInterval    // minutes
        let core: TimeInterval   // minutes
        let deep: TimeInterval   // minutes
        let awake: TimeInterval  // minutes
        let total: TimeInterval  // minutes
        let bedStart: Date?
        let bedEnd: Date?
    }

    struct SleepHeartRateData: Sendable {
        let samples: [(date: Date, bpm: Double)]
        let average: Double?
        let min: Double?
        let max: Double?
    }

    /// Query last night's sleep stages (REM, Core, Deep, Awake)
    func querySleepStages() async throws -> SleepStageData {
        // Look back 24 hours for last night's sleep
        let since = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: 500,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        var rem: TimeInterval = 0
        var core: TimeInterval = 0
        var deep: TimeInterval = 0
        var awake: TimeInterval = 0
        var bedStart: Date?
        var bedEnd: Date?

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60
            if bedStart == nil || sample.startDate < bedStart! { bedStart = sample.startDate }
            if bedEnd == nil || sample.endDate > bedEnd! { bedEnd = sample.endDate }

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                rem += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                core += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deep += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awake += duration
            default:
                // asleepUnspecified or inBed — count as core if asleep
                if sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue {
                    core += duration
                }
            }
        }

        let total = rem + core + deep
        return SleepStageData(rem: rem, core: core, deep: deep, awake: awake, total: total, bedStart: bedStart, bedEnd: bedEnd)
    }

    /// Query heart rate samples during last night's sleep window
    func querySleepHeartRate() async throws -> SleepHeartRateData {
        // First get sleep window
        let stages = try await querySleepStages()
        guard let start = stages.bedStart, let end = stages.bedEnd else {
            return SleepHeartRateData(samples: [], average: nil, min: nil, max: nil)
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let hrType = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())

        let hrSamples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: 1000,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }

        let tuples = hrSamples.map { (date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit)) }
        let bpms = tuples.map(\.bpm)
        let avg = bpms.isEmpty ? nil : bpms.reduce(0, +) / Double(bpms.count)
        let minBPM = bpms.min()
        let maxBPM = bpms.max()

        return SleepHeartRateData(samples: tuples, average: avg, min: minBPM, max: maxBPM)
    }

    private func averageHeartRate(for workout: HKWorkout) -> Double? {
        // Heart rate stats are available via workout metadata on newer watchOS
        if let stats = workout.statistics(for: HKQuantityType(.heartRate)),
           let avg = stats.averageQuantity() {
            return avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        return nil
    }

    private func maxHeartRate(for workout: HKWorkout) -> Double? {
        if let stats = workout.statistics(for: HKQuantityType(.heartRate)),
           let max = stats.maximumQuantity() {
            return max.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        return nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter.string(from: date)
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device."
        case .authorizationDenied:
            return "HealthKit access denied. Please enable in Settings > Privacy > Health."
        }
    }
}

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .highIntensityIntervalTraining: return "High Intensity Interval Training"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .yoga: return "Yoga"
        case .elliptical: return "Elliptical"
        case .swimming: return "Swimming"
        case .crossTraining: return "Cross Training"
        case .coreTraining: return "Core Training"
        case .stairClimbing: return "Stair Climbing"
        case .mixedCardio: return "Mixed Cardio"
        case .flexibility: return "Flexibility"
        default: return "Other"
        }
    }
}
