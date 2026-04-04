import SwiftUI
import Charts

// MARK: - Metric Detail Configuration

struct MetricConfig: @unchecked Sendable {
    let title: String
    let icon: String
    let iconColor: Color
    let unit: String
    let keyPath: KeyPath<DailyMetric, Double?>
    let relatedMetrics: [RelatedMetricConfig]
    let chartColor: Color
}

struct RelatedMetricConfig: @unchecked Sendable {
    let label: String
    let unit: String
    let keyPath: KeyPath<DailyMetric, Double?>
}

// MARK: - Preset Configurations

extension MetricConfig {
    static let sleep = MetricConfig(
        title: "Sleep",
        icon: "moon.fill",
        iconColor: Brand.secondary,
        unit: "hrs",
        keyPath: \.sleepHours,
        relatedMetrics: [
            .init(label: "Respiratory Rate", unit: "brpm", keyPath: \.respiratoryRate),
            .init(label: "SpO2", unit: "%", keyPath: \.spo2Normalized),
            .init(label: "Resting HR", unit: "bpm", keyPath: \.restingHeartRate),
        ],
        chartColor: Brand.secondary
    )

    static let restingHR = MetricConfig(
        title: "Resting Heart Rate",
        icon: "heart.fill",
        iconColor: Brand.critical,
        unit: "bpm",
        keyPath: \.restingHeartRate,
        relatedMetrics: [
            .init(label: "HRV", unit: "ms", keyPath: \.heartRateVariability),
            .init(label: "VO2 Max", unit: "mL/kg/min", keyPath: \.vo2Max),
            .init(label: "SpO2", unit: "%", keyPath: \.spo2Normalized),
        ],
        chartColor: Brand.critical
    )

    static let steps = MetricConfig(
        title: "Steps",
        icon: "figure.walk",
        iconColor: Brand.optimal,
        unit: "",
        keyPath: \.steps,
        relatedMetrics: [
            .init(label: "Distance", unit: "mi", keyPath: \.distanceMiles),
            .init(label: "Active Calories", unit: "kcal", keyPath: \.activeCalories),
            .init(label: "Exercise", unit: "min", keyPath: \.exerciseMinutes),
        ],
        chartColor: Brand.optimal
    )

    static let hrv = MetricConfig(
        title: "Heart Rate Variability",
        icon: "waveform.path.ecg",
        iconColor: Brand.accent,
        unit: "ms",
        keyPath: \.heartRateVariability,
        relatedMetrics: [
            .init(label: "Resting HR", unit: "bpm", keyPath: \.restingHeartRate),
            .init(label: "Sleep", unit: "hrs", keyPath: \.sleepHours),
            .init(label: "SpO2", unit: "%", keyPath: \.spo2Normalized),
        ],
        chartColor: Brand.accent
    )

    static let activeCalories = MetricConfig(
        title: "Active Calories",
        icon: "flame.fill",
        iconColor: Brand.critical,
        unit: "kcal",
        keyPath: \.activeCalories,
        relatedMetrics: [
            .init(label: "Steps", unit: "", keyPath: \.steps),
            .init(label: "Distance", unit: "mi", keyPath: \.distanceMiles),
            .init(label: "Exercise", unit: "min", keyPath: \.exerciseMinutes),
        ],
        chartColor: Brand.critical
    )
}

// MARK: - MetricDetailView

struct MetricDetailView: View {
    let config: MetricConfig
    let metrics: [DailyMetric]

    @State private var showLast30 = false
    @State private var selectedDate: String?

    private var displayMetrics: [DailyMetric] {
        let sorted = metrics.sorted { $0.date < $1.date }
        let count = showLast30 ? 30 : 7
        return Array(sorted.suffix(count))
    }

    private var todayValue: Double? {
        let todayStr = formatDate(Date())
        return metrics.first { $0.date == todayStr }?[keyPath: config.keyPath]
    }

    private var avg7: Double? {
        let sorted = metrics.sorted { $0.date < $1.date }
        let last7 = sorted.suffix(7).compactMap { $0[keyPath: config.keyPath] }
        guard !last7.isEmpty else { return nil }
        return last7.reduce(0, +) / Double(last7.count)
    }

    private var avg30: Double? {
        let sorted = metrics.sorted { $0.date < $1.date }
        let last30 = sorted.suffix(30).compactMap { $0[keyPath: config.keyPath] }
        guard !last30.isEmpty else { return nil }
        return last30.reduce(0, +) / Double(last30.count)
    }

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Current value
                    currentValueHeader

                    // Chart
                    chartCard

                    // Averages
                    averagesCard

                    // Related metrics
                    if !config.relatedMetrics.isEmpty {
                        relatedMetricsCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(config.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Current Value Header

    private var currentValueHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: config.icon)
                    .font(.title3)
                    .foregroundColor(config.iconColor)
                Text(formatValue(todayValue))
                    .font(.system(size: 48, weight: .bold).monospacedDigit())
                    .foregroundColor(Brand.textPrimary)
                if !config.unit.isEmpty {
                    Text(config.unit)
                        .font(.title3)
                        .foregroundColor(Brand.textMuted)
                        .offset(y: 8)
                }
            }
            Text("Today")
                .font(.caption)
                .foregroundColor(Brand.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(spacing: 12) {
            // 7/30 day toggle
            HStack(spacing: 0) {
                toggleButton("7 days", selected: !showLast30) { selectedDate = nil; showLast30 = false }
                toggleButton("30 days", selected: showLast30) { selectedDate = nil; showLast30 = true }
            }
            .background(Brand.elevated)
            .cornerRadius(8)

            // Selected value display (fixed position above chart)
            let dataPoints = displayMetrics.compactMap { metric -> (String, Double)? in
                guard let value = metric[keyPath: config.keyPath] else { return nil }
                return (metric.date, value)
            }

            if let selectedDate,
               let selectedValue = dataPoints.first(where: { $0.0 == selectedDate })?.1 {
                HStack(spacing: 6) {
                    Text(formatValue(selectedValue))
                        .font(.system(.title3, weight: .bold).monospacedDigit())
                        .foregroundColor(.white)
                    if !config.unit.isEmpty {
                        Text(config.unit)
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                    }
                    Text("·")
                        .foregroundColor(Brand.textMuted)
                    Text(shortDate(selectedDate))
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }

            if dataPoints.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(Brand.textMuted)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(dataPoints, id: \.0) { date, value in
                        LineMark(
                            x: .value("Date", date),
                            y: .value(config.title, value)
                        )
                        .foregroundStyle(config.chartColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Date", date),
                            y: .value(config.title, value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [config.chartColor.opacity(0.3), config.chartColor.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        PointMark(
                            x: .value("Date", date),
                            y: .value(config.title, value)
                        )
                        .foregroundStyle(selectedDate == date ? .white : config.chartColor)
                        .symbolSize(selectedDate == date ? 50 : (dataPoints.count <= 7 ? 30 : 0))
                    }

                    if let selectedDate {
                        RuleMark(x: .value("Date", selectedDate))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: showLast30 ? 4 : 7)) { value in
                        AxisValueLabel {
                            if let dateStr = value.as(String.self) {
                                Text(shortDate(dateStr))
                                    .font(.system(size: 9))
                                    .foregroundColor(Brand.textMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.04))
                        AxisValueLabel()
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(Brand.textMuted)
                    }
                }
                .frame(height: 200)
                .animation(.easeInOut(duration: 0.3), value: showLast30)
            }
        }
        .padding(16)
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func toggleButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(selected ? .white : Brand.textMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? config.chartColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
    }

    // MARK: - Averages

    private var averagesCard: some View {
        HStack(spacing: 0) {
            averageColumn(label: "Today", value: todayValue)
            divider
            averageColumn(label: "7-day avg", value: avg7)
            divider
            averageColumn(label: "30-day avg", value: avg30)
        }
        .padding(16)
        .background(Brand.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func averageColumn(label: String, value: Double?) -> some View {
        VStack(spacing: 4) {
            Text(formatValue(value))
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundColor(Brand.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 30)
    }

    // MARK: - Related Metrics

    private var relatedMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RELATED")
                .font(.caption.weight(.semibold))
                .foregroundColor(Brand.textMuted)

            let todayStr = formatDate(Date())
            let todayMetric = metrics.first { $0.date == todayStr }
            let sorted = metrics.sorted { $0.date < $1.date }
            let last7 = Array(sorted.suffix(7))

            ForEach(config.relatedMetrics, id: \.label) { related in
                let current = todayMetric?[keyPath: related.keyPath]
                let values = last7.compactMap { $0[keyPath: related.keyPath] }
                let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
                let trend = trendDirection(current: current, avg: avg)

                HStack {
                    Text(related.label)
                        .font(.subheadline)
                        .foregroundColor(Brand.textPrimary)

                    Spacer()

                    HStack(spacing: 6) {
                        Text(formatValue(current))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundColor(Brand.textPrimary)
                        if !related.unit.isEmpty {
                            Text(related.unit)
                                .font(.caption2)
                                .foregroundColor(Brand.textMuted)
                        }

                        if let trend {
                            Image(systemName: trend.icon)
                                .font(.system(size: 10))
                                .foregroundColor(trend.color)
                        }
                    }
                }
                .padding(.vertical, 4)

                if related.label != config.relatedMetrics.last?.label {
                    Divider().background(Color.white.opacity(0.04))
                }
            }
        }
        .padding(16)
        .background(Brand.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func trendDirection(current: Double?, avg: Double?) -> (icon: String, color: Color)? {
        guard let c = current, let a = avg, a > 0 else { return nil }
        let delta = (c - a) / a
        if delta > 0.05 { return ("arrow.up.right", Brand.optimal) }
        if delta < -0.05 { return ("arrow.down.right", Brand.critical) }
        return ("arrow.right", Brand.textMuted)
    }

    private func formatValue(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func shortDate(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: dateStr) else { return dateStr }
        let out = DateFormatter()
        out.dateFormat = "M/d"
        return out.string(from: date)
    }
}
