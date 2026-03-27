import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A0A0C).ignoresSafeArea()

                List {
                    Section {
                        HStack {
                            Text("Dashboard")
                                .foregroundColor(.white)
                            Spacer()
                            Link("Open", destination: URL(string: "https://vital-health-dashboard.vercel.app")!)
                                .font(.subheadline)
                                .foregroundColor(Color(hex: 0x00B4D8))
                        }
                        .listRowBackground(Color(hex: 0x141418))
                    } header: {
                        Text("Web App")
                            .foregroundColor(Color(hex: 0x606070))
                    }

                    Section {
                        HStack {
                            Text("Version")
                                .foregroundColor(.white)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(Color(hex: 0x606070))
                                .monospacedDigit()
                        }
                        .listRowBackground(Color(hex: 0x141418))

                        HStack {
                            Text("Sync Frequency")
                                .foregroundColor(.white)
                            Spacer()
                            Text("Hourly")
                                .foregroundColor(Color(hex: 0x606070))
                        }
                        .listRowBackground(Color(hex: 0x141418))
                    } header: {
                        Text("About")
                            .foregroundColor(Color(hex: 0x606070))
                    }

                    Section {
                        Button(role: .destructive) {
                            Task {
                                await authService.signOut()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Sign Out")
                                Spacer()
                            }
                        }
                        .listRowBackground(Color(hex: 0x141418))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: 0x00B4D8))
                }
            }
        }
    }
}
