import Foundation
import HealthKit

class HealthKitService: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.vo2Max),
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
        await MainActor.run { isAuthorized = true }
    }

    func enableBackgroundDelivery() {
        let quantityTypes: [HKQuantityType] = [
            .init(.heartRateVariabilitySDNN),
            .init(.restingHeartRate),
            .init(.stepCount),
            .init(.appleExerciseTime),
            .init(.activeEnergyBurned),
            .init(.vo2Max),
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

        let quantityMetrics: [(HKQuantityType, String, HKUnit)] = [
            (.init(.heartRateVariabilitySDNN), "heart_rate_variability", .secondUnit(with: .milli)),
            (.init(.restingHeartRate), "resting_heart_rate", HKUnit.count().unitDivided(by: .minute())),
            (.init(.stepCount), "step_count", .count()),
            (.init(.appleExerciseTime), "exercise_time", .minute()),
            (.init(.activeEnergyBurned), "active_energy_burned", .kilocalorie()),
            (.init(.vo2Max), "vo2_max", HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))),
        ]

        for (type, name, unit) in quantityMetrics {
            let samples = try await querySamples(type: type, since: startDate)
            if !samples.isEmpty {
                let metricSamples = samples.map { sample in
                    MetricSample(
                        date: formatDate(sample.startDate),
                        qty: sample.quantity.doubleValue(for: unit)
                    )
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
                limit: HKObjectQueryNoLimit,
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

    private func querySamples(type: HKQuantityType, since startDate: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
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
                limit: HKObjectQueryNoLimit,
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

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device."
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
