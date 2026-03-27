import SwiftUI

struct SyncStatusView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitService: HealthKitService
    @StateObject private var syncService: SyncService

    @State private var showSettings = false

    init() {
        // Placeholder — real init happens in .onAppear since we need environment objects
        _syncService = StateObject(wrappedValue: SyncService(
            healthKitService: HealthKitService(),
            authService: AuthService()
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A0A0C).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Sync status card
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(syncService.isSyncing
                                          ? Color(hex: 0x00B4D8).opacity(0.15)
                                          : Color(hex: 0x00D68F).opacity(0.15))
                                    .frame(width: 80, height: 80)

                                if syncService.isSyncing {
                                    ProgressView()
                                        .tint(Color(hex: 0x00B4D8))
                                        .scaleEffect(1.5)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(Color(hex: 0x00D68F))
                                }
                            }

                            VStack(spacing: 4) {
                                Text(syncService.isSyncing ? "Syncing..." : "Connected")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                if let lastSync = syncService.lastSyncDate {
                                    Text("Last sync: \(lastSync, style: .relative) ago")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: 0xA0A0B0))
                                } else {
                                    Text("Not synced yet")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: 0x606070))
                                }
                            }

                            Button {
                                Task { await syncService.sync() }
                            } label: {
                                Text("Sync Now")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: 0x00B4D8))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(syncService.isSyncing)
                            .opacity(syncService.isSyncing ? 0.5 : 1)
                        }
                        .padding(20)
                        .background(Color(hex: 0x141418))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )

                        // Sync log
                        if !syncService.syncLog.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Syncs")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color(hex: 0xA0A0B0))

                                ForEach(syncService.syncLog.prefix(5)) { entry in
                                    HStack {
                                        Circle()
                                            .fill(entry.success ? Color(hex: 0x00D68F) : Color(hex: 0xFF4757))
                                            .frame(width: 8, height: 8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            if entry.success {
                                                Text("\(entry.metricsUpdated) metrics, \(entry.workoutsCreated) workouts")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            } else {
                                                Text(entry.errorMessage ?? "Failed")
                                                    .font(.caption)
                                                    .foregroundColor(Color(hex: 0xFF4757))
                                            }
                                            Text(entry.date, style: .relative)
                                                .font(.caption2)
                                                .foregroundColor(Color(hex: 0x606070))
                                        }

                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(Color(hex: 0x141418))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Vital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(Color(hex: 0xA0A0B0))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .onAppear {
            // Wire up the real services and enable background delivery
            let realSync = SyncService(healthKitService: healthKitService, authService: authService)
            // Trigger initial sync if never synced
            if realSync.lastSyncDate == nil {
                Task { await realSync.sync() }
            }
            healthKitService.enableBackgroundDelivery()
        }
    }
}
