import SwiftUI

struct RecoveryRing: View {
    let score: Int
    let animateOnAppear: Bool

    @State private var animatedProgress: Double = 0

    init(score: Int, animateOnAppear: Bool = true) {
        self.score = score
        self.animateOnAppear = animateOnAppear
    }

    private var ringColor: Color {
        switch score {
        case 67...100: return Brand.optimal
        case 34...66: return Brand.warning
        default: return Brand.critical
        }
    }

    private var statusLabel: String {
        switch score {
        case 67...100: return "Optimal"
        case 34...66: return "Moderate"
        default: return "Low"
        }
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 12)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.4), radius: 6, x: 0, y: 0)

            // Score text
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Brand.textPrimary)

                Text(statusLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(ringColor)
            }
        }
        .onAppear {
            if animateOnAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    animatedProgress = Double(score) / 100.0
                }
            } else {
                animatedProgress = Double(score) / 100.0
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = Double(newValue) / 100.0
            }
        }
    }
}
