import SwiftUI
import UniformTypeIdentifiers

struct LabsView: View {
    @Environment(APIService.self) var apiService

    @State private var results: [LabResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedFilter: String = "All"
    @State private var showDocPicker = false
    @State private var isUploading = false
    @State private var uploadMessage: String?
    @State private var pickedFiles: [PickedFile] = []

    private let filterOptions = ["All", "Flagged", "Lipids", "Metabolic", "CBC", "Kidney", "Liver", "Hormones", "Thyroid", "Vitamins & Minerals", "Inflammation", "Infectious"]

    // Filtered results
    private var filteredResults: [LabResult] {
        switch selectedFilter {
        case "All":
            return results
        case "Flagged":
            return results.filter { $0.status == "Borderline" || $0.status == "Out of Range" || $0.status == "Critical" }
        default:
            return results.filter { $0.category == selectedFilter }
        }
    }

    // Group filtered results by category
    private var groupedResults: [(String, [LabResult])] {
        let grouped = Dictionary(grouping: filteredResults) { $0.category ?? "Other" }
        let order = ["Metabolic", "Lipids", "CBC", "Liver", "Kidney", "Hormones", "Thyroid", "Vitamins & Minerals", "Inflammation", "Infectious", "Other"]
        return order.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    // Summary counts
    private var statusCounts: (optimal: Int, inRange: Int, borderline: Int, outOfRange: Int) {
        var o = 0, i = 0, b = 0, r = 0
        for lab in results {
            switch lab.status {
            case "Optimal": o += 1
            case "In Range": i += 1
            case "Borderline": b += 1
            case "Out of Range", "Critical": r += 1
            default: break
            }
        }
        return (o, i, b, r)
    }

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            if isLoading {
                ListSkeleton()
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(Brand.critical)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if results.isEmpty && !isUploading {
                VStack(spacing: 16) {
                    EmptyStateView(
                        icon: "cross.case",
                        title: "No Lab Results",
                        subtitle: "Upload a lab PDF or screenshot to have it parsed automatically by AI.",
                        buttonTitle: "Upload Lab Results",
                        buttonAction: {
                            showDocPicker = true
                        }
                    )
                    if let msg = uploadMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(msg.contains("Error") || msg.contains("Failed") ? Brand.critical : Brand.optimal)
                            .padding(.horizontal, 16)
                            .multilineTextAlignment(.center)
                    }
                }
            } else if results.isEmpty && isUploading {
                VStack(spacing: 16) {
                    ProgressView().tint(Brand.accent)
                    Text("Parsing lab results with AI...")
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                    if let msg = uploadMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Upload button
                        uploadCard

                        // Summary card
                        summaryCard

                        // Draw date
                        if let drawDate = results.first?.drawDate {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(Brand.textMuted)
                                Text("Drawn \(formatDrawDate(drawDate))")
                                    .font(.caption)
                                    .foregroundColor(Brand.textMuted)
                                Spacer()
                                if let provider = results.first?.labProvider, !provider.isEmpty {
                                    Text(provider)
                                        .font(.caption)
                                        .foregroundColor(Brand.textMuted)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Category filter pills
                        filterPills

                        // Grouped results
                        ForEach(groupedResults, id: \.0) { category, labs in
                            categorySection(category: category, labs: labs)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Lab Results")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDocPicker) {
            DocumentPicker { urls in
                // Read file data NOW while security-scoped URLs are still valid
                var files: [PickedFile] = []
                for url in urls {
                    let accessed = url.startAccessingSecurityScopedResource()
                    if let data = try? Data(contentsOf: url) {
                        let ext = url.pathExtension.lowercased()
                        let ct = ext == "png" ? "image/png" : ext == "jpg" || ext == "jpeg" ? "image/jpeg" : "application/pdf"
                        let fn = ext == "png" ? "labs.png" : ext == "jpg" || ext == "jpeg" ? "labs.jpg" : "labs.pdf"
                        files.append(PickedFile(data: data, contentType: ct, filename: fn))
                    }
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                DispatchQueue.main.async {
                    pickedFiles = files
                }
            }
        }
        .onChange(of: pickedFiles) { _, files in
            guard !files.isEmpty else { return }
            Task {
                for file in files {
                    await uploadFileData(file)
                }
                pickedFiles = []
            }
        }
        .task {
            await loadLabs()
        }
    }

    // MARK: - Upload Card

    private var uploadCard: some View {
        VStack(spacing: 12) {
            if isUploading {
                HStack(spacing: 12) {
                    ProgressView().tint(Brand.secondary)
                    Text("Parsing lab results with AI...")
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Brand.card)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Brand.secondary.opacity(0.3), lineWidth: 1)
                )
            } else {
                Button {
                    showDocPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                            .foregroundColor(Brand.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upload Lab Results")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Brand.textPrimary)
                            Text("PDF or screenshot, auto-parsed by AI")
                                .font(.caption)
                                .foregroundColor(Brand.textMuted)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(Brand.secondary)
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [Brand.secondary.opacity(0.08), Brand.accent.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Brand.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
            }

            if let msg = uploadMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(msg.contains("Error") || msg.contains("Failed") ? Brand.critical : Brand.optimal)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Upload Logic

    private func uploadFileData(_ file: PickedFile) async {
        isUploading = true
        uploadMessage = nil

        do {
            // Build multipart form data
            let boundary = UUID().uuidString
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.contentType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            guard let token = await apiService.authService.accessToken() else {
                uploadMessage = "Error: Not signed in"
                isUploading = false
                return
            }

            var request = URLRequest(url: Config.apiBaseURL.appendingPathComponent("/labs/parse"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            request.timeoutInterval = 60

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                uploadMessage = "Error: \(errorBody)"
                isUploading = false
                return
            }

            // Parse response — contains parsed lab results
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let parseResponse = try decoder.decode(APIResponse<[LabResult]>.self, from: data)

            guard let parsed = parseResponse.data, !parsed.isEmpty else {
                uploadMessage = "No results found in PDF"
                isUploading = false
                return
            }

            // Save each parsed result via POST /api/labs
            var saved = 0
            for result in parsed {
                do {
                    let labBody: [String: Any?] = [
                        "testName": result.testName,
                        "yourValue": result.yourValue,
                        "unit": result.unit,
                        "labReferenceLow": result.labReferenceLow,
                        "labReferenceHigh": result.labReferenceHigh,
                        "optimalLow": result.optimalLow,
                        "optimalHigh": result.optimalHigh,
                        "status": result.status,
                        "category": result.category,
                        "drawDate": result.drawDate,
                        "labProvider": result.labProvider,
                        "notes": result.notes,
                    ]
                    let jsonData = try JSONSerialization.data(withJSONObject: labBody.compactMapValues { $0 })
                    let _: SuccessResponse = try await apiService.postRaw("/labs", jsonData: jsonData)
                    saved += 1
                } catch {
                    // Continue saving rest
                }
            }

            uploadMessage = "Parsed \(parsed.count) biomarkers, saved \(saved)"
            HapticManager.success()

            // Refresh
            await loadLabs()
        } catch {
            uploadMessage = "Failed: \(error.localizedDescription)"
        }

        isUploading = false
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let counts = statusCounts
        return HStack(spacing: 0) {
            statusPill(count: counts.optimal, label: "Optimal", color: Brand.optimal)
            statusPill(count: counts.inRange, label: "In Range", color: Brand.accent)
            statusPill(count: counts.borderline, label: "Borderline", color: Brand.warning)
            statusPill(count: counts.outOfRange, label: "Flag", color: Brand.critical)
        }
        .padding(12)
        .background(Brand.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func statusPill(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Brand.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterOptions, id: \.self) { option in
                    let count = option == "All" ? results.count :
                        option == "Flagged" ? results.filter({ $0.status == "Borderline" || $0.status == "Out of Range" || $0.status == "Critical" }).count :
                        results.filter({ $0.category == option }).count

                    if option == "All" || count > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = option
                            }
                        } label: {
                            Text(option == "All" ? "All" : "\(option) (\(count))")
                                .font(.caption.weight(.medium))
                                .foregroundColor(selectedFilter == option ? .white : Brand.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedFilter == option
                                        ? Brand.secondary
                                        : Brand.elevated
                                )
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(category: String, labs: [LabResult]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(Brand.textMuted)
                .padding(.leading, 4)

            VStack(spacing: 1) {
                ForEach(labs) { lab in
                    labRow(lab)
                }
            }
            .background(Brand.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func labRow(_ lab: LabResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: name, value, status badge
            HStack(alignment: .center) {
                Text(lab.testName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(1)

                Spacer()

                if let value = lab.yourValue {
                    Text(formatValue(value))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(Brand.textPrimary)

                    if let unit = lab.unit, !unit.isEmpty {
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(Brand.textMuted)
                    }
                }

                statusBadge(lab.status ?? "Unknown")
            }

            // Range bar
            if let value = lab.yourValue,
               let low = lab.labReferenceLow,
               let high = lab.labReferenceHigh,
               high > low {
                LabRangeBar(
                    value: value,
                    labLow: low,
                    labHigh: high,
                    optimalLow: lab.optimalLow,
                    optimalHigh: lab.optimalHigh,
                    status: lab.status ?? "Unknown"
                )
            }

            // Trend indicator
            if let trend = lab.trend, trend != "New" {
                HStack(spacing: 4) {
                    Image(systemName: trendIcon(trend))
                        .font(.system(size: 9))
                        .foregroundColor(trendColor(trend))
                    Text(trend)
                        .font(.system(size: 10))
                        .foregroundColor(trendColor(trend))
                }
            }
        }
        .padding(14)
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = switch status {
        case "Optimal": Brand.optimal
        case "In Range": Brand.accent
        case "Borderline": Brand.warning
        case "Out of Range", "Critical": Brand.critical
        default: Brand.textMuted
        }

        return Text(status == "Out of Range" ? "Flag" : status)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "Improving": return "arrow.up.right"
        case "Declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "Improving": return Brand.optimal
        case "Declining": return Brand.critical
        default: return Brand.textMuted
        }
    }

    // MARK: - Data

    private func loadLabs() async {
        do {
            let resp: APIResponse<[LabResult]> = try await apiService.get("/labs")
            results = resp.data ?? []
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func formatDrawDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateFormat = "MMM d, yyyy"
        return display.string(from: date)
    }
}

// MARK: - Picked File

struct PickedFile: Equatable {
    let data: Data
    let contentType: String
    let filename: String
}

// MARK: - Lab Range Bar (SwiftUI port of web RangeBar)

struct LabRangeBar: View {
    let value: Double
    let labLow: Double
    let labHigh: Double
    let optimalLow: Double?
    let optimalHigh: Double?
    let status: String

    @State private var animateBar = false
    @State private var animateDot = false

    private var statusColor: Color {
        switch status {
        case "Optimal": return Brand.optimal
        case "In Range": return Brand.accent
        case "Borderline": return Brand.warning
        default: return Brand.critical
        }
    }

    var body: some View {
        let range = labHigh - labLow
        let displayMin = labLow - range * 0.1
        let displayMax = labHigh + range * 0.1
        let displayRange = displayMax - displayMin

        let valuePos = (value - displayMin) / displayRange
        let clampedPos = max(0.02, min(0.98, valuePos))

        let labLowPos = (labLow - displayMin) / displayRange
        let labHighPos = (labHigh - displayMin) / displayRange

        VStack(spacing: 2) {
            GeometryReader { geo in
                let width = geo.size.width
                let midY: CGFloat = 6

                // Full lab range bar — animates width from 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: animateBar ? width * (labHighPos - labLowPos) : 0, height: 4)
                    .position(x: width * labLowPos + (animateBar ? width * (labHighPos - labLowPos) / 2 : 0), y: midY)

                // Optimal zone — fades in
                if let oLow = optimalLow, let oHigh = optimalHigh {
                    let oLowPos = (oLow - displayMin) / displayRange
                    let oHighPos = (oHigh - displayMin) / displayRange
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Brand.optimal.opacity(animateBar ? 0.15 : 0))
                        .frame(width: animateBar ? width * (oHighPos - oLowPos) : 0, height: 12)
                        .position(x: width * oLowPos + (animateBar ? width * (oHighPos - oLowPos) / 2 : 0), y: midY)
                }

                // Value dot — slides in from left edge to position
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: statusColor.opacity(0.4), radius: 4)
                    .scaleEffect(animateDot ? 1.0 : 0.3)
                    .opacity(animateDot ? 1.0 : 0)
                    .position(x: animateDot ? width * clampedPos : width * labLowPos, y: midY)
            }
            .frame(height: 12)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateBar = true
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                    animateDot = true
                }
            }

            // Scale labels
            HStack {
                Text(formatScale(labLow))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundColor(Brand.textMuted)
                Spacer()
                if let oLow = optimalLow, let oHigh = optimalHigh {
                    Text("\(formatScale(oLow))–\(formatScale(oHigh))")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundColor(Brand.optimal.opacity(0.5))
                }
                Spacer()
                Text(formatScale(labHigh))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundColor(Brand.textMuted)
            }
        }
    }

    private func formatScale(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
