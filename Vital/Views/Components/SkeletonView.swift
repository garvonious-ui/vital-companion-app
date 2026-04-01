import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.08),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 300)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Card

struct SkeletonCard: View {
    var height: CGFloat = 120

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Brand.card)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shimmer()
    }
}

// MARK: - Skeleton Row

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Brand.elevated)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Brand.elevated)
                    .frame(width: 140, height: 12)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Brand.elevated)
                    .frame(width: 90, height: 10)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Brand.elevated)
                .frame(width: 50, height: 12)
        }
        .padding(16)
        .background(Brand.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shimmer()
    }
}

// MARK: - Skeleton Bar

struct SkeletonBar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Brand.elevated)
                    .frame(width: 70, height: 12)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Brand.elevated)
                    .frame(width: 50, height: 12)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Brand.elevated)
                .frame(height: 6)
        }
        .shimmer()
    }
}

// MARK: - Dashboard Skeleton

struct DashboardSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Recovery ring placeholder
            SkeletonCard(height: 220)

            // Activity bars placeholder
            SkeletonCard(height: 160)

            // Sparkline charts placeholder
            SkeletonCard(height: 180)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - List Skeleton

struct ListSkeleton: View {
    var count: Int = 3

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .padding(.horizontal, 16)
    }
}
