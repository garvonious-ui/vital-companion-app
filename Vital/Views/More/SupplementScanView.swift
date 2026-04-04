import SwiftUI
import PhotosUI

struct SupplementScanView: View {
    @Environment(APIService.self) var apiService
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var results: [ScannedSupplement] = []
    @State private var isSaving = false
    @State private var savedCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if let image = capturedImage {
                    if isAnalyzing {
                        analyzingView(image: image)
                    } else if !results.isEmpty {
                        resultsView(image: image)
                    } else if let error = errorMessage {
                        errorView(image: image, error: error)
                    }
                } else {
                    captureView
                }
            }
            .navigationTitle("Scan Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.accent)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    capturedImage = image
                    HapticManager.medium()
                    Task { await analyze(image) }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                        HapticManager.medium()
                        await analyze(image)
                    }
                }
            }
        }
    }

    // MARK: - Capture View

    private var captureView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "pill.fill")
                .font(.system(size: 50))
                .foregroundColor(Brand.accent.opacity(0.5))

            Text("Take a photo of your supplements")
                .font(.headline)
                .foregroundColor(Brand.textPrimary)

            Text("We'll identify each bottle and auto-fill your supplement stack")
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Brand.accent)
                    .cornerRadius(12)
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(Brand.accent)
                    .background(Brand.card)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Brand.accent.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Analyzing View

    private func analyzingView(image: UIImage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Brand.accent.opacity(0.3), lineWidth: 2)
                )
                .scaleEffect(1.02)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnalyzing)

            ProgressView()
                .tint(Brand.accent)

            Text("Identifying supplements...")
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Results View

    private func resultsView(image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Photo thumbnail
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .cornerRadius(12)

                Text("\(results.count) supplements identified")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Brand.textPrimary)

                // Results list
                ForEach($results) { $supp in
                    supplementResultCard(supp: $supp)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Brand.critical)
                }

                // Save button
                Button {
                    Task { await saveAll() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            let selected = results.filter(\.selected).count
                            Text("Save \(selected) Supplement\(selected == 1 ? "" : "s")")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(results.filter(\.selected).isEmpty ? Brand.textMuted : Brand.accent)
                    .cornerRadius(12)
                }
                .disabled(results.filter(\.selected).isEmpty || isSaving)

                // Retake button
                Button {
                    capturedImage = nil
                    results = []
                    errorMessage = nil
                    selectedPhoto = nil
                } label: {
                    Text("Retake Photo")
                        .font(.subheadline)
                        .foregroundColor(Brand.accent)
                }
            }
            .padding(16)
        }
    }

    private func supplementResultCard(supp: Binding<ScannedSupplement>) -> some View {
        HStack(spacing: 12) {
            // Toggle
            Button {
                supp.wrappedValue.selected.toggle()
            } label: {
                Image(systemName: supp.wrappedValue.selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(supp.wrappedValue.selected ? Brand.accent : Brand.textMuted)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(supp.wrappedValue.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Brand.textPrimary)

                HStack(spacing: 8) {
                    if !supp.wrappedValue.dosage.isEmpty {
                        Text(supp.wrappedValue.dosage)
                            .foregroundColor(Brand.accent)
                    }
                    Text(supp.wrappedValue.type)
                        .foregroundColor(Brand.textMuted)
                    Text(supp.wrappedValue.timing)
                        .foregroundColor(Brand.textMuted)
                }
                .font(.caption)

                if let reason = supp.wrappedValue.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(Brand.textSecondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Brand.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(supp.wrappedValue.selected ? Brand.accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Error View

    private func errorView(image: UIImage, error: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 150)
                .cornerRadius(12)
                .opacity(0.5)

            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(Brand.warning)

            Text(error)
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                capturedImage = nil
                errorMessage = nil
                selectedPhoto = nil
            } label: {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Brand.accent)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Analyze

    private func analyze(_ image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        results = []

        guard let compressed = compressImage(image) else {
            errorMessage = "Failed to compress image"
            isAnalyzing = false
            return
        }

        guard let token = await authService.accessToken() else {
            errorMessage = "Not signed in"
            isAnalyzing = false
            return
        }

        let base64 = compressed.base64EncodedString()

        do {
            var request = URLRequest(url: URL(string: "\(Config.apiBaseURL)/supplements/analyze")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 60
            request.httpBody = try JSONSerialization.data(withJSONObject: ["image": base64])

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let decoded = try? JSONDecoder().decode(SupplementAnalysisResponse.self, from: data)
                errorMessage = decoded?.error ?? "Analysis failed"
                isAnalyzing = false
                return
            }

            let decoded = try JSONDecoder().decode(SupplementAnalysisResponse.self, from: data)

            if decoded.success, let analysis = decoded.data {
                results = analysis.supplements.map { ScannedSupplement(from: $0) }
                HapticManager.success()
            } else {
                errorMessage = decoded.error ?? "Analysis failed"
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    // MARK: - Save

    private func saveAll() async {
        isSaving = true
        errorMessage = nil
        savedCount = 0

        let selected = results.filter(\.selected)

        for supp in selected {
            let validTypes = ["Prescription", "Supplement", "OTC"]
            let validTimings = ["Morning", "Afternoon", "Evening", "With Food", "Empty Stomach"]

            let type = validTypes.first { $0.lowercased() == supp.type.lowercased() } ?? "Supplement"
            let timing = validTimings.first { $0.lowercased() == supp.timing.lowercased() } ?? mapTiming(supp.timing)

            let body: [String: String] = [
                "name": supp.name,
                "type": type,
                "dosage": supp.dosage,
                "frequency": supp.frequency,
                "timing": timing,
                "status": "Active",
                "reason": supp.reason ?? "",
            ]

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                let _: SuccessResponse = try await apiService.postRaw("/supplements", jsonData: jsonData)
                savedCount += 1
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }

        if savedCount > 0 {
            HapticManager.success()
            dismiss()
        } else if errorMessage == nil {
            errorMessage = "Failed to save supplements"
        }

        isSaving = false
    }

    // MARK: - Timing Mapper

    private func mapTiming(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("morning") { return "Morning" }
        if lower.contains("evening") || lower.contains("night") || lower.contains("bed") { return "Evening" }
        if lower.contains("afternoon") { return "Afternoon" }
        if lower.contains("meal") || lower.contains("food") { return "With Food" }
        if lower.contains("empty") || lower.contains("fasting") { return "Empty Stomach" }
        return "Morning" // safe default
    }

    // MARK: - Image Compression

    private func compressImage(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1024
        let size = image.size
        let scale: CGFloat = max(size.width, size.height) > maxDimension
            ? maxDimension / max(size.width, size.height)
            : 1.0

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Models

struct SupplementAnalysisResponse: Codable {
    let success: Bool
    let data: SupplementAnalysisData?
    let error: String?
}

struct SupplementAnalysisData: Codable {
    let supplements: [AnalyzedSupplement]
    let confidence: String
    let notes: String?
}

struct AnalyzedSupplement: Codable {
    let name: String
    let type: String
    let dosage: String
    let frequency: String
    let timing: String
    let reason: String?
    let brand: String?
}

struct ScannedSupplement: Identifiable {
    let id = UUID()
    var name: String
    var type: String
    var dosage: String
    var frequency: String
    var timing: String
    var reason: String?
    var selected: Bool = true

    init(from analyzed: AnalyzedSupplement) {
        self.name = analyzed.brand != nil ? "\(analyzed.name) (\(analyzed.brand!))" : analyzed.name
        self.type = analyzed.type
        self.dosage = analyzed.dosage
        self.frequency = analyzed.frequency
        self.timing = analyzed.timing
        self.reason = analyzed.reason
    }
}
