import SwiftUI
import UIKit

// MARK: - Models

struct MealAnalysisResponse: Codable, Sendable {
    let success: Bool
    let data: MealAnalysis?
    let error: String?
    let code: String?
    let remaining: Int?
}

struct MealAnalysis: Codable, Sendable {
    let mealName: String
    let confidence: String
    let items: [MealItem]
    let totals: MealTotals
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case confidence, items, totals, notes
    }
}

struct MealItem: Codable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var estimatedPortion: String
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int

    enum CodingKeys: String, CodingKey {
        case name
        case estimatedPortion = "estimated_portion"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try c.decode(String.self, forKey: .name)
        estimatedPortion = try c.decode(String.self, forKey: .estimatedPortion)
        calories = try c.decode(Int.self, forKey: .calories)
        proteinG = try c.decode(Int.self, forKey: .proteinG)
        carbsG = try c.decode(Int.self, forKey: .carbsG)
        fatG = try c.decode(Int.self, forKey: .fatG)
    }

    init(name: String, estimatedPortion: String, calories: Int, proteinG: Int, carbsG: Int, fatG: Int) {
        self.name = name
        self.estimatedPortion = estimatedPortion
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}

struct MealTotals: Codable, Sendable {
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
}

// MARK: - Service

@MainActor
@Observable class MealAnalysisService {
    var isAnalyzing = false
    var error: String?
    var result: MealAnalysis?
    var remaining: Int?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    /// Compress and analyze a meal photo
    func analyze(image: UIImage) async {
        isAnalyzing = true
        error = nil
        result = nil

        guard let compressed = compressImage(image) else {
            error = "Failed to compress image"
            isAnalyzing = false
            return
        }

        guard let token = await authService.accessToken() else {
            error = "Not signed in"
            isAnalyzing = false
            return
        }

        let base64 = compressed.base64EncodedString()

        do {
            var request = URLRequest(url: URL(string: "\(Config.apiBaseURL)/nutrition/analyze-meal")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 60

            let body: [String: Any] = [
                "image": base64,
                "user_context": ["portion_preference": "male_standard"]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isAnalyzing = false
                return
            }

            if httpResponse.statusCode == 429 {
                let decoded = try JSONDecoder().decode(MealAnalysisResponse.self, from: data)
                error = decoded.error ?? "Daily scan limit reached"
                remaining = 0
                isAnalyzing = false
                return
            }

            let decoded = try JSONDecoder().decode(MealAnalysisResponse.self, from: data)

            if decoded.success, let analysis = decoded.data {
                result = analysis
                remaining = decoded.remaining
            } else {
                error = decoded.error ?? "Analysis failed"
            }
        } catch {
            self.error = "Network error: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    /// Resize to max 1024px on longest side, JPEG quality 0.8
    private func compressImage(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1024
        let size = image.size
        let scale: CGFloat

        if size.width > size.height {
            scale = size.width > maxDimension ? maxDimension / size.width : 1.0
        } else {
            scale = size.height > maxDimension ? maxDimension / size.height : 1.0
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: 0.8)
    }

    /// Auto-detect meal type based on time of day
    static func suggestedMealType() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<11: return "Breakfast"
        case 11..<14: return "Lunch"
        case 14..<17: return "Snack"
        default: return "Dinner"
        }
    }
}
