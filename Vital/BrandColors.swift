import SwiftUI

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Brand colors — True Midnight palette
enum Brand {
    // Functional (status)
    static let optimal = Color(hex: 0xC9A84C)        // Soft gold — good/optimal
    static let warning = Color(hex: 0xE0A840)         // Bright gold — warning/borderline
    static let critical = Color(hex: 0xD45A5A)        // Muted red — critical/flag
    static let accent = Color(hex: 0x8B8AE5)          // Periwinkle — primary interactive
    static let secondary = Color(hex: 0xC9A84C)       // Soft gold — secondary interactive

    // Surfaces
    static let bg = Color(hex: 0x080C1E)
    static let card = Color(hex: 0x111530)
    static let elevated = Color(hex: 0x1A1E40)

    // Text
    static let textPrimary = Color(hex: 0xD8D8F0)     // Light lavender white
    static let textSecondary = Color(hex: 0x8888B0)
    static let textMuted = Color(hex: 0x555578)

    // Gradients
    static let askVitalGradient = LinearGradient(
        colors: [Color(hex: 0x6868C0), Color(hex: 0x8B8AE5)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let avatarGradient = LinearGradient(
        colors: [Color(hex: 0xC9A84C), Color(hex: 0x8B8AE5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
