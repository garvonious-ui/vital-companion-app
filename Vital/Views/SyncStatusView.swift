import SwiftUI

struct SyncStatusView: View {
    @Environment(AuthService.self) var authService
    @Environment(HealthKitService.self) var healthKitService
    @Environment(SyncService.self) var syncService

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Sync status card
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(syncService.isSyncing
                                          ? Brand.accent.opacity(0.15)
                                          : Brand.optimal.opacity(0.15))
                                    .frame(width: 80, height: 80)

                                if syncService.isSyncing {
                                    ProgressView()
                                        .tint(Brand.accent)
                                        .scaleEffect(1.5)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(Brand.optimal)
                                }
                            }

                            VStack(spacing: 4) {
                                Text(syncService.isSyncing ? "Syncing..." : "Connected")
                                    .font(.headline)
                                    .foregroundColor(Brand.textPrimary)

                                if let lastSync = syncService.lastSyncDate {
                                    Text("Last sync: \(lastSync, style: .relative) ago")
                                        .font(.caption)
                                        .foregroundColor(Brand.textSecondary)
                                } else {
                                    Text("Not synced yet")
                                        .font(.caption)
                                        .foregroundColor(Brand.textMuted)
                                }
                            }

                            Button {
                                Task { await syncService.sync() }
                            } label: {
                                Text("Sync Now")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Brand.accent)
                                    .foregroundColor(Brand.textPrimary)
                                    .cornerRadius(10)
                            }
                            .disabled(syncService.isSyncing)
                            .opacity(syncService.isSyncing ? 0.5 : 1)
                        }
                        .padding(20)
                        .background(Brand.card)
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
                                    .foregroundColor(Brand.textSecondary)

                                ForEach(syncService.syncLog.prefix(5)) { entry in
                                    HStack {
                                        Circle()
                                            .fill(entry.success ? Brand.optimal : Brand.critical)
                                            .frame(width: 8, height: 8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            if entry.success {
                                                Text("\(entry.metricsUpdated) metrics, \(entry.workoutsCreated) workouts")
                                                    .font(.caption)
                                                    .foregroundColor(Brand.textPrimary)
                                            } else {
                                                Text(entry.errorMessage ?? "Failed")
                                                    .font(.caption)
                                                    .foregroundColor(Brand.critical)
                                            }
                                            Text(entry.date, style: .relative)
                                                .font(.caption2)
                                                .foregroundColor(Brand.textMuted)
                                        }

                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(Brand.card)
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
                            .foregroundColor(Brand.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .onAppear {
            healthKitService.enableBackgroundDelivery()
            if syncService.lastSyncDate == nil {
                Task { await syncService.sync() }
            }
        }
    }
}
