import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @State private var isRequesting = false
    @State private var errorMessage: String?

    private let metrics: [(String, String, String)] = [
        ("heart.fill", "Heart Rate Variability", "HRV trends for recovery tracking"),
        ("heart.circle", "Resting Heart Rate", "Daily resting HR baseline"),
        ("figure.walk", "Steps", "Daily step count"),
        ("flame.fill", "Active Energy", "Calories burned from activity"),
        ("timer", "Exercise Minutes", "Apple Exercise ring data"),
        ("lungs.fill", "VO2 Max", "Cardiovascular fitness"),
        ("moon.fill", "Sleep", "Sleep duration and quality"),
        ("figure.run", "Workouts", "Workout type, duration, heart rate"),
    ]

    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0C).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                Text("Health Access")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Vital needs read access to sync your Apple Health data to your dashboard.")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: 0xA0A0B0))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(metrics, id: \.1) { icon, name, description in
                            HStack(spacing: 14) {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundColor(Color(hex: 0x00B4D8))
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(Color(hex: 0x606070))
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(Color(hex: 0x141418))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(hex: 0xFF4757))
                }

                Button {
                    isRequesting = true
                    Task {
                        do {
                            try await healthKitService.requestAuthorization()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isRequesting = false
                    }
                } label: {
                    HStack {
                        if isRequesting {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        }
                        Text("Grant Access")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: 0x00D68F))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isRequesting)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}
