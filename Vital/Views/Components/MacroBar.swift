import SwiftUI

struct MacroBar: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color
    let unit: String

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color(hex: 0xA0A0B0))

                Spacer()

                HStack(spacing: 2) {
                    Text(formatValue(current))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    Text("/ \(formatValue(target)) \(unit)")
                        .font(.caption2)
                        .foregroundColor(Color(hex: 0x606070))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)

                    // Fill
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value == value.rounded() {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
