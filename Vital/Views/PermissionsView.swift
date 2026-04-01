import SwiftUI

struct PermissionsView: View {
    @Environment(HealthKitService.self) var healthKitService
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
            Brand.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                Text("Health Access")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Brand.textPrimary)

                Text("Vital needs read access to sync your Apple Health data to your dashboard.")
                    .font(.subheadline)
                    .foregroundColor(Brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(metrics, id: \.1) { icon, name, description in
                            HStack(spacing: 14) {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundColor(Brand.accent)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(Brand.textPrimary)
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(Brand.textMuted)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(Brand.card)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Brand.critical)
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
                    .background(Brand.optimal)
                    .foregroundColor(Brand.textPrimary)
                    .cornerRadius(12)
                }
                .disabled(isRequesting)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}
