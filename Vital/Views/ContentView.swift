import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitService: HealthKitService

    var body: some View {
        Group {
            if authService.isLoading {
                ZStack {
                    Color(hex: 0x0A0A0C).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            } else if !authService.isSignedIn {
                LoginView()
            } else if !healthKitService.isAuthorized {
                PermissionsView()
            } else {
                SyncStatusView()
            }
        }
    }
}

// Color extension for hex values
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
