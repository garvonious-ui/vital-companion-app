import SwiftUI

struct SupplementsView: View {
    @Environment(APIService.self) var apiService

    @State private var supplements: [Supplement] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddForm = false
    @State private var editingSupplement: Supplement?
    @State private var deleteTarget: Supplement?

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
            Brand.bg.ignoresSafeArea()

            if isLoading {
                ListSkeleton(count: 4)
                    .padding(.top, 16)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Brand.warning)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                    Button("Retry") { Task { await loadData() } }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Brand.accent)
                        .foregroundColor(Brand.textPrimary)
                        .cornerRadius(10)
                }
            } else if activeSupplements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pill")
                        .font(.largeTitle)
                        .foregroundColor(Brand.textMuted)
                    Text("No supplements")
                        .font(.subheadline)
                        .foregroundColor(Brand.textMuted)
                    Text("Add supplements on the web dashboard")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Count header
                        HStack {
                            Text("\(activeSupplements.count) active supplements")
                                .font(.caption)
                                .foregroundColor(Brand.textMuted)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddForm = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Brand.accent)
                }
            }
        }
        .sheet(isPresented: $showAddForm, onDismiss: {
            Task { await loadData() }
        }) {
            SupplementFormView(supplement: nil)
        }
        .sheet(item: $editingSupplement, onDismiss: {
            Task { await loadData() }
        }) { supp in
            SupplementFormView(supplement: supp, onDelete: { target in
                Task { await deleteSupplement(target) }
            })
        }
        .confirmationDialog("Delete \(deleteTarget?.name ?? "supplement")?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let supp = deleteTarget {
                    Task {
                        await deleteSupplement(supp)
                        deleteTarget = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
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
                    .foregroundColor(Brand.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ForEach(items) { supp in
                supplementRow(supp)
            }

            Spacer().frame(height: 8)
        }
        .background(Brand.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func supplementRow(_ supp: Supplement) -> some View {
        Button {
            editingSupplement = supp
        } label: {
        HStack(spacing: 12) {
            // Type badge
            Text(suppTypeEmoji(supp.type))
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Brand.elevated)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(supp.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Brand.textPrimary)

                HStack(spacing: 8) {
                    if let dosage = supp.dosage, !dosage.isEmpty {
                        Text(dosage)
                            .foregroundColor(Brand.accent)
                    }
                    if let type = supp.type, !type.isEmpty {
                        Text(type.capitalized)
                            .foregroundColor(Brand.textMuted)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Brand.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        } // close Button label
    }

    @ViewBuilder
    private func timingIcon(_ timing: String) -> some View {
        let (icon, color): (String, Color) = {
            switch timing.lowercased() {
            case "morning": return ("sunrise.fill", Brand.warning)
            case "with meals": return ("fork.knife", Brand.accent)
            case "pre-workout": return ("bolt.fill", Brand.critical)
            case "post-workout": return ("arrow.down.circle.fill", Brand.optimal)
            case "evening": return ("moon.fill", Brand.secondary)
            default: return ("clock", Brand.textSecondary)
            }
        }()

        Image(systemName: icon)
            .font(.caption)
            .foregroundColor(color)
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

    private func deleteSupplement(_ supp: Supplement) async {
        do {
            let _: SuccessResponse = try await apiService.delete("/supplements", queryItems: [URLQueryItem(name: "id", value: supp.id)])
            supplements.removeAll { $0.id == supp.id }
            HapticManager.success()
        } catch {
            // Silently fail — user can retry
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
