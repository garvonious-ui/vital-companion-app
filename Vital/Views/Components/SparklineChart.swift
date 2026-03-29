import SwiftUI
import Charts

struct SparklineChart: View {
    let dataPoints: [Double]
    let color: Color
    let label: String
    let unit: String
    let latestValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color(hex: 0xA0A0B0))

                Spacer()

                Text(latestValue)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(.white)

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(Color(hex: 0x606070))
            }

            if dataPoints.count >= 2 {
                Chart {
                    ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Day", index),
                            y: .value(label, value)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", index),
                            y: .value(label, value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 40)
            } else {
                Rectangle()
                    .fill(Color(hex: 0x1C1C22))
                    .frame(height: 40)
                    .overlay(
                        Text("Not enough data")
                            .font(.caption2)
                            .foregroundColor(Color(hex: 0x606070))
                    )
            }
        }
    }
}
