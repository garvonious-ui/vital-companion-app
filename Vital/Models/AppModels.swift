import Foundation

// MARK: - Generic API Response

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
}

// MARK: - Daily Metrics

struct DailyMetric: Codable, Identifiable {
    var id: String { date }
    let date: String
    let steps: Double?
    let heartRate: Double?
    let heartRateVariability: Double?
    let restingHeartRate: Double?
    let activeEnergy: Double?
    let exerciseMinutes: Double?
    let sleepHours: Double?
    let bodyMass: Double?
}

// MARK: - Targets

struct UserTargets: Codable {
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fat: Int?
    let steps: Int?
    let exerciseMinutes: Int?
    let sleepHours: Double?
    let water: Int?
}

// MARK: - Workouts

struct Workout: Codable, Identifiable {
    let id: String
    let userId: String?
    let type: String
    let name: String?
    let duration: Int?  // minutes
    let calories: Int?
    let date: String
    let notes: String?
    let exercises: [WorkoutExercise]?
    let createdAt: String?
}

struct WorkoutExercise: Codable, Identifiable {
    let id: String
    let name: String
    let sets: [ExerciseSet]?
    let order: Int?
}

struct ExerciseSet: Codable, Identifiable {
    let id: String
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let completed: Bool?
}

// MARK: - Workout Plans

struct WorkoutPlan: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let daysPerWeek: Int?
    let days: [PlanDay]?
    let createdAt: String?
}

struct PlanDay: Codable, Identifiable {
    let id: String
    let dayNumber: Int
    let name: String
    let exercises: [PlanExercise]?
}

struct PlanExercise: Codable, Identifiable {
    let id: String
    let name: String
    let sets: Int
    let reps: String  // e.g. "8-12"
    let restSeconds: Int?
    let order: Int?
}

// MARK: - Exercise Library

struct LibraryExercise: Codable, Identifiable {
    let id: String
    let name: String
    let muscleGroup: String?
    let equipment: String?
    let category: String?
}

// MARK: - Nutrition

struct NutritionEntry: Codable, Identifiable {
    let id: String
    let userId: String?
    let date: String
    let mealType: String  // breakfast, lunch, dinner, snack, shake
    let name: String
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let createdAt: String?
}

struct NutritionLogBody: Codable {
    let date: String
    let mealType: String
    let name: String
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
}

// MARK: - Supplements

struct Supplement: Codable, Identifiable {
    let id: String
    let name: String
    let type: String?        // vitamin, mineral, herb, amino acid, etc.
    let dosage: String?
    let timing: String?      // morning, evening, with meals, etc.
    let active: Bool?
    let notes: String?
}

// MARK: - User Profile

struct UserProfile: Codable {
    let id: String
    let email: String?
    let name: String?
    let age: Int?
    let height: Double?
    let weight: Double?
    let goal: String?
    let createdAt: String?
}

// MARK: - AI Chat

struct ChatRequest: Codable {
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
