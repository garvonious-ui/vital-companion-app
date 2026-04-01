import SwiftUI

struct WaterQuickAddView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    @State private var currentOz: Double = 0
    @State private var targetOz: Double = 100
    @State private var customAmount = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var weeklyWater: [(String, Double)] = [] // (day label, oz)
    @State private var animateBars = false

    private var progress: Double {
        targetOz > 0 ? min(currentOz / targetOz, 1.0) : 0
    }

    private var goalReached: Bool {
        currentOz >= targetOz && targetOz > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    // Progress ring
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.06), lineWidth: 8)
                                .frame(width: 140, height: 140)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    goalReached ? Brand.optimal : Brand.accent,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 0.5), value: progress)

                            VStack(spacing: 2) {
                                if goalReached {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(Brand.optimal)
                                }
                                Text("\(Int(currentOz))")
                                    .font(.system(size: 36, weight: .bold).monospacedDigit())
                                    .foregroundColor(goalReached ? Brand.optimal : Brand.textPrimary)
                                Text("of \(Int(targetOz)) oz")
                                    .font(.caption)
                                    .foregroundColor(Brand.textMuted)
                            }
                        }

                        Text("Daily Goal")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Brand.textMuted)

                        if goalReached {
                            Text("Goal reached!")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Brand.optimal)
                        }
                    }

                    // Weekly streak
                    if !weeklyWater.isEmpty {
                        weeklyStreak
                    }

                    // Quick add buttons
                    HStack(spacing: 16) {
                        quickButton(8)
                        quickButton(16)
                        quickButton(24)
                    }
                    .padding(.horizontal, 8)

                    // Custom amount
                    HStack(spacing: 12) {
                        TextField("Custom oz", text: $customAmount)
                            .textFieldStyle(DarkFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 120)

                        Button {
                            if let amount = Double(customAmount), amount > 0 {
                                Task { await addWater(amount) }
                                customAmount = ""
                            }
                        } label: {
                            Text("Add")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(customAmount.isEmpty ? Brand.textMuted : Brand.accent)
                                .cornerRadius(10)
                        }
                        .disabled(customAmount.isEmpty)
                    }

                    Spacer()
                }
                .padding(24)
                .opacity(isLoading ? 0.5 : 1)
                .overlay {
                    if isLoading {
                        ProgressView().tint(Brand.textPrimary)
                    }
                }
            }
            .navigationTitle("Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Brand.accent)
                }
            }
            .task {
                await loadCurrentWater()
            }
        }
    }

    // MARK: - Quick Button

    private func quickButton(_ oz: Int) -> some View {
        Button(action: {
            HapticManager.light()
            Task { await addWater(Double(oz)) }
        }) {
            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .foregroundColor(Brand.accent)
                Text("\(oz) oz")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Brand.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .disabled(isSaving)
    }

    // MARK: - Weekly Streak

    private var weeklyStreak: some View {
        let barHeight: CGFloat = 40

        return HStack(spacing: 6) {
            ForEach(weeklyWater, id: \.0) { day, oz in
                let filled = targetOz > 0 ? min(oz / targetOz, 1.0) : 0
                let isToday = day == todayLabel
                let fillColor = filled >= 1.0 ? Brand.optimal : (oz > 0 ? Brand.accent.opacity(0.5) : Color.white.opacity(0.06))

                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        // Background track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.04))
                            .frame(height: barHeight)

                        // Filled bar — animates from 0 to actual height
                        RoundedRectangle(cornerRadius: 3)
                            .fill(fillColor)
                            .frame(height: animateBars ? max(barHeight * filled, 2) : 2)
                    }
                    .frame(height: barHeight)
                    .clipped()

                    Text(day)
                        .font(.system(size: 9, weight: isToday ? .bold : .regular))
                        .foregroundColor(isToday ? Brand.accent : Brand.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Brand.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateBars = true
            }
        }
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: Date())
    }

    // MARK: - Data

    private func addWater(_ oz: Double) async {
        isSaving = true
        let newTotal = currentOz + oz

        let todayStr = formatDate(Date())
        let body: [String: Any] = ["date": todayStr, "waterOz": newTotal]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let _: APIResponse<String?> = try await apiService.patchRaw("/metrics", jsonData: jsonData)
            withAnimation { currentOz = newTotal }
            HapticManager.success()
        } catch {
            print("Water add failed: \(error)")
        }
        isSaving = false
    }

    private func loadCurrentWater() async {
        do {
            let metricsResp: APIResponse<[DailyMetric]> = try await apiService.get("/metrics")
            let targetsResp: APIResponse<UserTargets> = try await apiService.get("/targets")

            let allMetrics = metricsResp.data ?? []
            let todayStr = formatDate(Date())
            if let today = allMetrics.first(where: { $0.date == todayStr }) {
                currentOz = today.waterOz ?? 0
            }
            targetOz = Double(targetsResp.data?.waterOz ?? 100)

            // Build weekly data (last 7 days)
            let calendar = Calendar.current
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            var weekly: [(String, Double)] = []
            for i in (0..<7).reversed() {
                let date = calendar.date(byAdding: .day, value: -i, to: Date())!
                let dateStr = dateFormatter.string(from: date)
                let label = dayFormatter.string(from: date)
                let oz = allMetrics.first(where: { $0.date == dateStr })?.waterOz ?? 0
                weekly.append((label, oz))
            }
            weeklyWater = weekly
        } catch {
            // Non-critical
        }
        isLoading = false
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
