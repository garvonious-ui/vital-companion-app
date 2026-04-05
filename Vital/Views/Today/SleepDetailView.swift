import SwiftUI
import Charts

struct SleepDetailView: View {
    @Environment(HealthKitService.self) var healthKitService
    @Environment(APIService.self) var apiService

    @State private var stages: HealthKitService.SleepStageData?
    @State private var heartRate: HealthKitService.SleepHeartRateData?
    @State private var weeklyMetrics: [DailyMetric] = []
    @State private var isLoading = true
    @State private var animateBars = false

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Brand.accent)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        sleepSummaryCard
                        if stages != nil { stagesCard }
                        if heartRate != nil { heartRateCard }
                        weeklyChart
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Summary Card

    private var sleepSummaryCard: some View {
        VStack(spacing: 16) {
            if let s = stages {
                HStack(spacing: 4) {
                    Text(formatHoursMinutes(s.total))
                        .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(Brand.textPrimary)
                    Text("total sleep")
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                        .padding(.top, 14)
                }

                if let start = s.bedStart, let end = s.bedEnd {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("Bedtime")
                                .font(.caption2)
                                .foregroundColor(Brand.textMuted)
                            Text(formatTime(start))
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .foregroundColor(Brand.textSecondary)
                        }
                        Rectangle()
                            .fill(Brand.textMuted.opacity(0.3))
                            .frame(width: 1, height: 24)
                        VStack(spacing: 2) {
                            Text("Wake")
                                .font(.caption2)
                                .foregroundColor(Brand.textMuted)
                            Text(formatTime(end))
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .foregroundColor(Brand.textSecondary)
                        }
                    }
                }
            } else {
                Text("No sleep data for last night")
                    .font(.subheadline)
                    .foregroundColor(Brand.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Stages Card

    private var stagesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Stages")
                .font(.headline)
                .foregroundColor(Brand.textPrimary)

            if let s = stages, s.total > 0 {
                // Stage bars
                VStack(spacing: 10) {
                    stageRow(label: "REM", minutes: s.rem, total: s.total, color: Brand.secondary)
                    stageRow(label: "Core", minutes: s.core, total: s.total, color: Brand.accent)
                    stageRow(label: "Deep", minutes: s.deep, total: s.total, color: Brand.accent.opacity(0.7))
                    stageRow(label: "Awake", minutes: s.awake, total: s.total + s.awake, color: Brand.warning.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.6)) { animateBars = true }
            }
        }
    }

    private func stageRow(label: String, minutes: TimeInterval, total: TimeInterval, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(Brand.textSecondary)
                .frame(width: 48, alignment: .leading)

            GeometryReader { geo in
                let fraction = total > 0 ? minutes / total : 0
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: animateBars ? geo.size.width * fraction : 0)
            }
            .frame(height: 20)
            .background(Brand.elevated.cornerRadius(4))

            Text(formatMinutes(minutes))
                .font(.caption.monospacedDigit())
                .foregroundColor(Brand.textMuted)
                .frame(width: 48, alignment: .trailing)
        }
    }

    // MARK: - Heart Rate Card

    private var heartRateCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Heart Rate")
                .font(.headline)
                .foregroundColor(Brand.textPrimary)

            if let hr = heartRate, !hr.samples.isEmpty {
                // Stats row
                HStack(spacing: 0) {
                    hrStat(label: "Avg", value: hr.average, color: Brand.accent)
                    Spacer()
                    hrStat(label: "Min", value: hr.min, color: Brand.optimal)
                    Spacer()
                    hrStat(label: "Max", value: hr.max, color: Brand.critical)
                }

                // Chart
                Chart {
                    ForEach(Array(hr.samples.enumerated()), id: \.offset) { _, sample in
                        LineMark(
                            x: .value("Time", sample.date),
                            y: .value("BPM", sample.bpm)
                        )
                        .foregroundStyle(Brand.critical.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))

                        AreaMark(
                            x: .value("Time", sample.date),
                            y: .value("BPM", sample.bpm)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Brand.critical.opacity(0.3), Brand.critical.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatTime(date))
                                    .font(.caption2)
                                    .foregroundColor(Brand.textMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let bpm = value.as(Double.self) {
                                Text("\(Int(bpm))")
                                    .font(.caption2)
                                    .foregroundColor(Brand.textMuted)
                            }
                        }
                    }
                }
                .frame(height: 160)
            } else {
                Text("No heart rate data during sleep")
                    .font(.subheadline)
                    .foregroundColor(Brand.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func hrStat(label: String, value: Double?, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
            Text(value.map { "\(Int($0))" } ?? "—")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(color)
            Text("bpm")
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last 7 Days")
                .font(.headline)
                .foregroundColor(Brand.textPrimary)

            if weeklyMetrics.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(Brand.textSecondary)
            } else {
                Chart {
                    ForEach(weeklyMetrics) { metric in
                        BarMark(
                            x: .value("Date", shortDate(metric.date)),
                            y: .value("Hours", metric.sleepHours ?? 0)
                        )
                        .foregroundStyle(Brand.secondary.opacity(0.8))
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let hrs = value.as(Double.self) {
                                Text("\(Int(hrs))h")
                                    .font(.caption2)
                                    .foregroundColor(Brand.textMuted)
                            }
                        }
                    }
                }
                .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Data Loading

    private func loadData() async {
        async let stagesResult = healthKitService.querySleepStages()
        async let hrResult = healthKitService.querySleepHeartRate()
        async let metricsResult: APIResponse<[DailyMetric]> = apiService.get("/metrics", queryItems: [URLQueryItem(name: "days", value: "7")])

        do { stages = try await stagesResult } catch { if !(error is CancellationError) { print("[SleepDetail] stages error: \(error)") } }
        do { heartRate = try await hrResult } catch { if !(error is CancellationError) { print("[SleepDetail] HR error: \(error)") } }
        do { weeklyMetrics = try await metricsResult.data ?? [] } catch { if !(error is CancellationError) { print("[SleepDetail] metrics error: \(error)") } }

        isLoading = false
    }

    // MARK: - Formatters

    private func formatHoursMinutes(_ minutes: TimeInterval) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return "\(h)h \(m)m"
    }

    private func formatMinutes(_ minutes: TimeInterval) -> String {
        let m = Int(minutes)
        if m >= 60 {
            return "\(m / 60)h \(m % 60)m"
        }
        return "\(m)m"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func shortDate(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: dateStr) else { return dateStr }
        let out = DateFormatter()
        out.dateFormat = "EEE"
        return out.string(from: date)
    }
}
