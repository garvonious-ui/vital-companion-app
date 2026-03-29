import SwiftUI

struct SupplementsView: View {
    @EnvironmentObject var apiService: APIService

    @State private var supplements: [Supplement] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var activeSupplements: [Supplement] {
        supplements.filter { $0.active != false }
    }

    private var groupedByTiming: [(String, [Supplement])] {
        let timings = ["morning", "with meals", "pre-workout", "post-workout", "evening", "as needed"]
        var result: [(String, [Supplement])] = []

        for timing in timings {
            let items = activeSupplements.filter { ($0.timing?.lowercased() ?? "as needed") == timing }
            if !items.isEmpty {
                result.append((timing, items))
            }
        }

        // Catch any supplements with non-standard timing
        let coveredIds = Set(result.flatMap { $0.1.map(\.id) })
        let uncovered = activeSupplements.filter { !coveredIds.contains($0.id) }
        if !uncovered.isEmpty {
            result.append(("other", uncovered))
        }

        return result
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0C).ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Color(hex: 0xFFB547))
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: 0xA0A0B0))
                    Button("Retry") { Task { await loadData() } }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(hex: 0x00B4D8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else if activeSupplements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pill")
                        .font(.largeTitle)
                        .foregroundColor(Color(hex: 0x606070))
                    Text("No supplements")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: 0x606070))
                    Text("Add supplements on the web dashboard")
                        .font(.caption)
                        .foregroundColor(Color(hex: 0x606070))
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Count header
                        HStack {
                            Text("\(activeSupplements.count) active supplements")
                                .font(.caption)
                                .foregroundColor(Color(hex: 0x606070))
                            Spacer()
                        }

                        ForEach(groupedByTiming, id: \.0) { timing, items in
                            timingSection(timing: timing, items: items)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await loadData()
                }
            }
        }
        .navigationTitle("Supplements")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func timingSection(timing: String, items: [Supplement]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                timingIcon(timing)
                Text(timing.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: 0xA0A0B0))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ForEach(items) { supp in
                supplementRow(supp)
            }

            Spacer().frame(height: 8)
        }
        .background(Color(hex: 0x141418))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func supplementRow(_ supp: Supplement) -> some View {
        HStack(spacing: 12) {
            // Type badge
            Text(suppTypeEmoji(supp.type))
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color(hex: 0x1C1C22))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(supp.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    if let dosage = supp.dosage, !dosage.isEmpty {
                        Text(dosage)
                            .foregroundColor(Color(hex: 0x00B4D8))
                    }
                    if let type = supp.type, !type.isEmpty {
                        Text(type.capitalized)
                            .foregroundColor(Color(hex: 0x606070))
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func timingIcon(_ timing: String) -> some View {
        let (icon, color): (String, UInt) = {
            switch timing.lowercased() {
            case "morning": return ("sunrise.fill", 0xFFB547)
            case "with meals": return ("fork.knife", 0x00B4D8)
            case "pre-workout": return ("bolt.fill", 0xFF4757)
            case "post-workout": return ("arrow.down.circle.fill", 0x00D68F)
            case "evening": return ("moon.fill", 0x8B5CF6)
            default: return ("clock", 0xA0A0B0)
            }
        }()

        Image(systemName: icon)
            .font(.caption)
            .foregroundColor(Color(hex: color))
    }

    private func suppTypeEmoji(_ type: String?) -> String {
        switch type?.lowercased() {
        case "vitamin": return "💊"
        case "mineral": return "🪨"
        case "herb": return "🌿"
        case "amino acid": return "⚡"
        case "protein": return "🥩"
        case "omega", "fatty acid": return "🐟"
        case "probiotic": return "🦠"
        default: return "💊"
        }
    }

    private func loadData() async {
        isLoading = supplements.isEmpty
        errorMessage = nil

        do {
            let resp: APIResponse<[Supplement]> = try await apiService.get("/supplements")
            supplements = resp.data ?? []
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
