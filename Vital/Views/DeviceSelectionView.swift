import SwiftUI
import AuthenticationServices

struct DeviceSelectionView: View {
    @Environment(HealthKitService.self) var healthKitService
    @Environment(AuthService.self) var authService
    @State private var isRequestingHealthKit = false
    @State private var isConnectingOura = false
    @State private var errorMessage: String?
    @State private var showHealthKitPrompt = false
    @State private var pendingHealthKitDevice: DeviceType?
    @State private var primerApproved = false

    let onComplete: (DeviceType) -> Void

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Header
                    Image(systemName: "applewatch.and.arrow.forward")
                        .font(.system(size: 40))
                        .foregroundColor(Brand.accent)

                    Text("How do you track?")
                        .font(.title2.weight(.bold))
                        .foregroundColor(Brand.textPrimary)

                    Text("Connect your device so Vital can pull your health data automatically.")
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        // Apple Watch
                        deviceButton(
                            icon: "applewatch",
                            title: "Apple Watch",
                            subtitle: "Syncs sleep, heart rate, HRV, steps, workouts via HealthKit",
                            color: Brand.accent
                        ) {
                            pendingHealthKitDevice = .appleWatch
                            showHealthKitPrompt = true
                        }

                        // Oura Ring
                        deviceButton(
                            icon: "circle.circle",
                            title: "Oura Ring",
                            subtitle: isConnectingOura ? "Connecting..." : "Syncs sleep, readiness, heart rate, HRV, SpO2",
                            color: Brand.secondary
                        ) {
                            Task { await connectOura() }
                        }

                        // Whoop
                        deviceButton(
                            icon: "waveform.path",
                            title: "Whoop",
                            subtitle: "Enable Apple Health sharing in your Whoop app first, then connect here",
                            color: Brand.optimal
                        ) {
                            pendingHealthKitDevice = .appleWatch
                            showHealthKitPrompt = true
                        }

                        // Just iPhone
                        deviceButton(
                            icon: "iphone",
                            title: "Just my iPhone",
                            subtitle: "Basic step counting and distance from your phone's sensors",
                            color: Brand.textSecondary
                        ) {
                            pendingHealthKitDevice = .iPhone
                            showHealthKitPrompt = true
                        }

                        // No device
                        Button {
                            onComplete(.none)
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundColor(Brand.textMuted)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Brand.critical)
                            .padding(.horizontal, 24)
                    }

                    Spacer()
                }
            }
        }
        .sheet(
            isPresented: $showHealthKitPrompt,
            onDismiss: handlePrimerDismiss
        ) {
            HealthKitPrimerSheet(
                onContinue: {
                    primerApproved = true
                    showHealthKitPrompt = false
                },
                onCancel: {
                    primerApproved = false
                    showHealthKitPrompt = false
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func deviceButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Brand.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }
            .padding(16)
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .disabled(isRequestingHealthKit)
    }

    // Called after the primer sheet finishes dismissing. Deferring the
    // HealthKit auth call here prevents iOS from dropping the native prompt
    // when it would otherwise stack on top of an animating-away sheet.
    private func handlePrimerDismiss() {
        guard primerApproved, let device = pendingHealthKitDevice else {
            pendingHealthKitDevice = nil
            return
        }
        primerApproved = false
        pendingHealthKitDevice = nil
        Task {
            if device == .iPhone {
                await connectiPhone()
            } else {
                await connectAppleWatch()
            }
        }
    }

    private func connectAppleWatch() async {
        isRequestingHealthKit = true
        defer { isRequestingHealthKit = false }

        do {
            try await healthKitService.requestAuthorization()
            HapticManager.success()
            onComplete(.appleWatch)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func connectOura() async {
        isConnectingOura = true
        defer { isConnectingOura = false }

        guard let token = await authService.accessToken() else {
            errorMessage = "Not signed in"
            return
        }

        let urlString = "\(Config.apiBaseURL)/devices/oura/connect-mobile?token=\(token)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        // Use ASWebAuthenticationSession for OAuth
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: nil
            ) { _, error in
                // User either completed OAuth or cancelled
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    // User cancelled — that's fine if they already authorized
                }
                continuation.resume()
            }
            session.presentationContextProvider = OuraAuthPresenter.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // After the browser closes, assume success and proceed
        HapticManager.success()
        onComplete(.oura)
    }

    private func connectiPhone() async {
        isRequestingHealthKit = true
        defer { isRequestingHealthKit = false }

        do {
            try await healthKitService.requestAuthorization()
            HapticManager.success()
            onComplete(.iPhone)
        } catch {
            // iPhone users can proceed even if HealthKit denied
            onComplete(.iPhone)
        }
    }
}

// MARK: - Auth Presenter

class OuraAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OuraAuthPresenter()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - HealthKit Primer

/// Educational screen shown immediately before iOS's HealthKit permission
/// prompt. Apple's sheet shows every data-type toggle OFF by default and the
/// app can't detect which toggles the user flipped — so users who tap "Allow"
/// without flipping any on end up with zero permissions granted, and iOS won't
/// re-show the prompt. This screen tells them to use "Turn On All" up front.
private struct HealthKitPrimerSheet: View {
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer().frame(height: 8)

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Brand.accent)

                Text("One quick step")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Brand.textPrimary)

                Text("Apple will ask which health data to share with Vital.")
                    .font(.subheadline)
                    .foregroundColor(Brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Callout card
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Brand.optimal)
                        Text("Tap **Turn On All**")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Brand.textPrimary)
                        Spacer()
                    }
                    Text("Every toggle is OFF by default. If you skip this, Vital can't read any of your data and we can't show you a recovery score, workouts, or trends.")
                        .font(.caption)
                        .foregroundColor(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Brand.optimal.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Brand.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(Brand.textMuted)
                }
                .padding(.bottom, 12)
            }
            .padding(.top, 24)
        }
    }
}

// MARK: - Device Type

enum DeviceType: String, Codable {
    case appleWatch
    case oura
    case iPhone
    case none

    var shouldSyncHealthKit: Bool {
        self == .appleWatch || self == .iPhone
    }
}
