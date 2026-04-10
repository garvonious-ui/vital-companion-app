import SwiftUI

/// Animated splash shown while `AuthService.isLoading` is true.
///
/// Replaces the previous `ProgressView()` spinner. Designed for the slow paths
/// — first-install launches where Supabase is provisioning a session, HealthKit
/// is doing first-auth handshakes, and Vercel functions are cold. A static
/// spinner makes those seconds feel endless; a subtle breathing animation
/// papers over them and frames the wait as intentional.
///
/// The logo mark (gradient circle + "V") matches `LoginView` so there is no
/// visual snap when the splash hands off to the auth screen.
struct SplashView: View {
    @State private var breathe = false
    @State private var appeared = false
    @State private var messageIndex = 0

    private let messages = [
        "Loading",
        "Syncing your data",
        "Almost ready",
    ]

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            // Ambient periwinkle glow behind the logo. Gives the dark bg depth
            // during the hold and pulses in sync with the logo's breath.
            RadialGradient(
                colors: [
                    Brand.accent.opacity(breathe ? 0.22 : 0.10),
                    Brand.bg.opacity(0),
                ],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            .animation(
                .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: breathe
            )

            VStack(spacing: 24) {
                logoMark

                Text("VITAL")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(8)
                    .foregroundColor(Brand.textPrimary)
                    .padding(.top, 8)

                // Rotating status line. `id(messageIndex)` forces SwiftUI to
                // treat each message as a new view, so the transition fires.
                Text(messages[messageIndex].uppercased())
                    .font(.footnote.weight(.medium))
                    .tracking(2)
                    .foregroundColor(Brand.textMuted)
                    .id(messageIndex)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        )
                    )
                    .padding(.top, 32)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            // Fade the content in first, then start the breathing loop.
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
            // Slight delay so the fade-in doesn't fight the repeat-forever loop.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                breathe = true
            }
        }
        .task {
            // Cycle status messages every ~1.8s while the splash is visible.
            // Auto-cancels when AuthService.isLoading flips false and SwiftUI
            // tears the view down.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.8))
                if Task.isCancelled { break }
                withAnimation(.easeInOut(duration: 0.4)) {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }

    // MARK: - Logo Mark

    private var logoMark: some View {
        ZStack {
            // Blurred halo behind the gradient circle — expands and contracts
            // with the breath, giving the mark a soft aura.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Brand.accent.opacity(0.5),
                            Brand.secondary.opacity(0.5),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .blur(radius: 28)
                .scaleEffect(breathe ? 1.08 : 0.92)

            // Main gradient circle — matches the LoginView mark.
            Circle()
                .fill(Brand.avatarGradient)
                .frame(width: 88, height: 88)
                .scaleEffect(breathe ? 1.04 : 0.96)
                .shadow(color: Brand.accent.opacity(0.4), radius: 16, x: 0, y: 4)

            Text("V")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(Brand.textPrimary)
                .scaleEffect(breathe ? 1.02 : 0.98)
        }
        .animation(
            .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
            value: breathe
        )
    }
}

#Preview {
    SplashView()
}
