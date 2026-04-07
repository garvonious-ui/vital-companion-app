import SwiftUI
import AuthenticationServices

struct DeviceSelectionView: View {
    @Environment(HealthKitService.self) var healthKitService
    @Environment(AuthService.self) var authService
    @State private var isRequestingHealthKit = false
    @State private var isConnectingOura = false
    @State private var errorMessage: String?

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
                            Task { await connectAppleWatch() }
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

                        // Just iPhone
                        deviceButton(
                            icon: "iphone",
                            title: "Just my iPhone",
                            subtitle: "Basic step counting and distance from your phone's sensors",
                            color: Brand.textSecondary
                        ) {
                            Task { await connectiPhone() }
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
