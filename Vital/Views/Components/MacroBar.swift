import SwiftUI

struct MacroBar: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color
    let unit: String

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Brand.textSecondary)

                Spacer()

                HStack(spacing: 2) {
                    Text(formatValue(current))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(Brand.textPrimary)

                    Text("/ \(formatValue(target)) \(unit)")
                        .font(.caption2)
                        .foregroundColor(Brand.textMuted)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)

                    // Fill — animated width
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * animatedProgress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: current) { _, _ in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = progress
            }
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
