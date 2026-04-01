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

/// Brand colors — Emerald Health palette
enum Brand {
    // Functional (status)
    static let optimal = Color(hex: 0x5AB88C)        // Sage green — good/optimal
    static let warning = Color(hex: 0xE0A840)         // Bright gold — warning/borderline
    static let critical = Color(hex: 0xD45A5A)        // Muted red — critical/flag
    static let accent = Color(hex: 0x5BA88C)          // Emerald — primary interactive
    static let secondary = Color(hex: 0xC8923A)       // Dark amber — secondary interactive

    // Surfaces
    static let bg = Color(hex: 0x0E1210)
    static let card = Color(hex: 0x161E1A)
    static let elevated = Color(hex: 0x1E2824)

    // Text
    static let textPrimary = Color(hex: 0xE8F0EC)     // Cream-green white
    static let textSecondary = Color(hex: 0x8FA898)
    static let textMuted = Color(hex: 0x5A6E62)

    // Gradients
    static let askVitalGradient = LinearGradient(
        colors: [Color(hex: 0x3D7A5E), Color(hex: 0x78B8A2)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let avatarGradient = LinearGradient(
        colors: [Color(hex: 0x3D7A5E), Color(hex: 0x5AB88C)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
