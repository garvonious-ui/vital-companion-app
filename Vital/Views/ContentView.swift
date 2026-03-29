import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var apiService: APIService

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
                MainTabView()
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var apiService: APIService

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "heart.circle.fill")
                    Text("Dashboard")
                }
                .tag(0)

            WorkoutsView()
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("Workouts")
                }
                .tag(1)

            NutritionView()
                .tabItem {
                    Image(systemName: "fork.knife")
                    Text("Nutrition")
                }
                .tag(2)

            MoreView()
                .tabItem {
                    Image(systemName: "ellipsis.circle.fill")
                    Text("More")
                }
                .tag(3)
        }
        .tint(Color(hex: 0x00B4D8))
        .onAppear {
            // Style the tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color(hex: 0x0A0A0C))
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color(hex: 0x606070))
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: 0x606070))]
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
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
