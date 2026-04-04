import Foundation

// MARK: - Generic API Response

struct APIResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let success: Bool
    let data: T?
    let error: String?
}

/// For endpoints that return `{ success: true }` with no data field
struct SuccessResponse: Decodable, Sendable {
    let success: Bool
    let error: String?
}

// MARK: - Daily Metrics
// API returns: id, date, weightLbs, sleepHours, sleepQuality, hrvMs, restingHR, vo2Max,
//              steps, activeCalories, exerciseMinutes, waterOz, mood, energy, focus, notes

struct DailyMetric: Codable, Identifiable, Sendable {
    let id: String
    let date: String
    let weightLbs: Double?
    let sleepHours: Double?
    let sleepQuality: String?
    let hrvMs: Double?
    let restingHR: Double?
    let vo2Max: Double?
    let steps: Double?
    let activeCalories: Double?
    let exerciseMinutes: Double?
    let distanceMiles: Double?
    let spo2: Double?
    let respiratoryRate: Double?
    let waterOz: Double?
    let mood: Int?
    let energy: Int?
    let focus: Int?
    let notes: String?

    // Convenience aliases used by DashboardView
    var heartRateVariability: Double? { hrvMs }
    var restingHeartRate: Double? { restingHR }
}

// MARK: - Targets
// API returns: caloriesMin, caloriesMax, proteinMin, proteinMax, waterOz,
//              steps, sleepHoursMin, sleepHoursMax, exerciseMinutesPerWeek

struct UserTargets: Codable, Sendable {
    let caloriesMin: Int?
    let caloriesMax: Int?
    let proteinMin: Int?
    let proteinMax: Int?
    let waterOz: Int?
    let steps: Int?
    let sleepHoursMin: Double?
    let sleepHoursMax: Double?
    let exerciseMinutesPerWeek: Int?

    // Convenience for views that expect single values
    var calories: Int? { caloriesMax }
    var protein: Int? { proteinMax }
    var exerciseMinutes: Int? { exerciseMinutesPerWeek.map { $0 / 7 } }
    var carbs: Int? { caloriesMax.map { Int(Double($0) * 0.4 / 4) } }
    var fat: Int? { caloriesMax.map { Int(Double($0) * 0.25 / 9) } }
}

// MARK: - Workouts
// API returns: id, workoutName, date, type, durationMin, activeCalories,
//              avgHeartRate, maxHeartRate, muscleGroups, source, notes

struct Workout: Codable, Identifiable, Sendable {
    let id: String
    let workoutName: String?
    let date: String
    let type: String?
    let durationMin: Int?
    let activeCalories: Int?
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let muscleGroups: [String]?
    let source: String?
    let notes: String?

    // Convenience aliases
    var name: String? { workoutName }
    var duration: Int? { durationMin }
    var calories: Int? { activeCalories }
}

// MARK: - Exercise Log Entry (from exercise_log table via /api/exercises)

struct ExerciseLogEntry: Codable, Identifiable, Sendable {
    let id: String
    let exercise: String
    let workoutDate: String?
    let muscleGroup: String?
    let sets: Int?
    let reps: String?
    let weightLbs: Double?
    let restSec: Int?
    let notes: String?
}

struct ExerciseLogBody: Codable, Sendable {
    let exercise: String
    let workoutDate: String
    let muscleGroup: String?
    let sets: Int?
    let reps: String?
    let weightLbs: Double?
    let restSec: Int?
    let notes: String?
}

// MARK: - Exercise Log (used by WorkoutDetail and WorkoutSession)

struct WorkoutExercise: Codable, Identifiable, Sendable {
    var id: String { "\(order ?? 0)-\(name)" }
    let name: String
    let sets: [ExerciseSet]?
    let order: Int?
}

struct ExerciseSet: Codable, Identifiable, Sendable {
    var id: String { "\(setNumber)" }
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let completed: Bool?
}

// MARK: - Workout Plans
// API returns: id, planName, planData (JSON), questionnaire (JSON), isActive, createdAt

struct WorkoutPlan: Codable, Identifiable, Sendable {
    let id: String
    let planName: String?
    let planData: PlanData?
    let isActive: Bool?
    let createdAt: String?

    var name: String { planName ?? "Unnamed Plan" }
}

struct PlanData: Codable, Sendable {
    let planName: String?
    let notes: String?
    let days: [PlanDay]?
}

struct PlanDay: Codable, Identifiable, Sendable {
    var id: String { "\(dayNumber)-\(name)" }
    let dayNumber: Int
    let name: String
    let isRest: Bool?
    let exercises: [PlanExercise]?
}

struct PlanExercise: Codable, Identifiable, Sendable {
    var id: String { "\(order ?? 0)-\(name)" }
    let name: String
    let sets: Int?
    let reps: String?
    let restSeconds: Int?
    let order: Int?
    let equipment: String?
    let notes: String?
}

// MARK: - Exercise Library
// API returns: id, exerciseName, primaryMuscle, secondaryMuscles, equipment, movementType

struct LibraryExercise: Codable, Identifiable, Sendable {
    let id: String
    let exerciseName: String?
    let primaryMuscle: String?
    let secondaryMuscles: [String]?
    let equipment: String?
    let movementType: String?

    var name: String { exerciseName ?? "Unknown" }
    var muscleGroup: String? { primaryMuscle }
}

// MARK: - Nutrition
// API returns: id, meal, date, mealType, calories, proteinG, carbsG, fatG, waterOz, notes

struct NutritionEntry: Codable, Identifiable, Sendable {
    let id: String
    let meal: String?
    let date: String
    let mealType: String?
    let calories: Int?
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let waterOz: Double?
    let notes: String?

    // Convenience aliases
    var name: String { meal ?? "Meal" }
    var protein: Double? { proteinG }
    var carbs: Double? { carbsG }
    var fat: Double? { fatG }
}

struct NutritionLogBody: Codable, Sendable {
    let date: String
    let mealType: String
    let meal: String
    let calories: Int?
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
}

// MARK: - Supplements
// API returns: id, name, type, dosage, frequency, timing, status, reason, startDate, notes

struct Supplement: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let type: String?
    let dosage: String?
    let frequency: String?
    let timing: String?
    let status: String?
    let reason: String?
    let startDate: String?
    let notes: String?

    var active: Bool { status == "Active" }
}

// MARK: - User Profile
// API returns: id, displayName, dateOfBirth, sex, heightInches, weightLbs,
//              location, goals, conditions, medications

struct UserProfile: Codable, Sendable {
    let id: String
    let displayName: String?
    let dateOfBirth: String?
    let sex: String?
    let heightInches: Double?
    let weightLbs: Double?
    let location: String?
    let goals: [String]?
    let conditions: [String]?
    let medications: [String]?

    // Convenience aliases
    var name: String? { displayName }
    var email: String? { nil } // Not in profiles table
    var weight: Double? { weightLbs }
    var goal: String? { goals?.first }
}

// MARK: - Lab Results
// API returns: id, testName, yourValue, unit, labReferenceLow, labReferenceHigh,
//              optimalLow, optimalHigh, status, trend, category, drawDate, labProvider, notes

struct LabResult: Codable, Identifiable, Sendable {
    let id: String
    let testName: String
    let yourValue: Double?
    let unit: String?
    let labReferenceLow: Double?
    let labReferenceHigh: Double?
    let optimalLow: Double?
    let optimalHigh: Double?
    let status: String?
    let trend: String?
    let category: String?
    let drawDate: String?
    let labProvider: String?
    let notes: String?
}

// MARK: - AI Chat

struct ChatRequest: Codable, Sendable {
    let message: String
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    var content: String
    let timestamp: Date

    init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

enum ChatRole {
    case user
    case assistant
}
