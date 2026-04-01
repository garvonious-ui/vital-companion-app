import SwiftUI
import PhotosUI

struct MealAnalysisView: View {
    @Environment(APIService.self) var apiService
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss

    @State private var analysisService: MealAnalysisService
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    // Editable results
    @State private var mealName = ""
    @State private var mealType: String
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var items: [MealItem] = []
    @State private var confidence = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var resultsAppeared = false

    let onSaved: (() -> Void)?

    init(authService: AuthService, onSaved: (() -> Void)? = nil) {
        _analysisService = State(wrappedValue: MealAnalysisService(authService: authService))
        _mealType = State(initialValue: MealAnalysisService.suggestedMealType())
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if analysisService.isAnalyzing {
                    analyzingView
                } else if let result = analysisService.result {
                    resultsView(result)
                } else if let error = analysisService.error {
                    errorView(error)
                } else {
                    // Initial state — show capture options
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Brand.textMuted)

                        Text("Take or choose a photo of your meal")
                            .font(.subheadline)
                            .foregroundColor(Brand.textSecondary)

                        VStack(spacing: 12) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Brand.accent)
                                    .foregroundColor(Brand.bg)
                                    .cornerRadius(12)
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Brand.card)
                                    .foregroundColor(Brand.textPrimary)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.textMuted.opacity(0.3), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 40)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Scan Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.accent)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    capturedImage = image
                    HapticManager.medium()
                    Task { await analysisService.analyze(image: image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                        HapticManager.medium()
                        await analysisService.analyze(image: image)
                    }
                }
            }
        }
    }

    // MARK: - Analyzing State

    @State private var pulsePhoto = false
    @State private var statusMessageIndex = 0
    private let statusMessages = [
        "Identifying food items...",
        "Estimating portions...",
        "Calculating macros...",
        "Almost there..."
    ]

    private var analyzingView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.black.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Brand.accent.opacity(0.6), lineWidth: 2)
                            .scaleEffect(pulsePhoto ? 1.08 : 1.0)
                            .opacity(pulsePhoto ? 0.0 : 1.0)
                    )
                    .scaleEffect(pulsePhoto ? 1.02 : 0.98)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulsePhoto)
            }

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Brand.accent)
                    Text("Analyzing...")
                        .font(.headline)
                        .foregroundColor(Brand.textPrimary)
                }

                Text(statusMessages[statusMessageIndex])
                    .font(.subheadline)
                    .foregroundColor(Brand.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: statusMessageIndex)
            }

            Spacer()
        }
        .onAppear {
            pulsePhoto = true
            HapticManager.light()
            // Cycle through status messages
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
                if !analysisService.isAnalyzing {
                    timer.invalidate()
                    return
                }
                withAnimation {
                    statusMessageIndex = (statusMessageIndex + 1) % statusMessages.count
                }
            }
        }
    }

    // MARK: - Results

    private func resultsView(_ result: MealAnalysis) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Photo + confidence
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                confidenceBadge(result.confidence)

                // Meal name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meal Name")
                        .font(.caption)
                        .foregroundColor(Brand.textSecondary)
                    TextField("Meal name", text: $mealName)
                        .font(.headline)
                        .foregroundColor(Brand.textPrimary)
                        .padding(12)
                        .background(Brand.card)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.textMuted.opacity(0.3), lineWidth: 1))
                }

                // Meal type picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meal Type")
                        .font(.caption)
                        .foregroundColor(Brand.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(["Breakfast", "Lunch", "Dinner", "Snack", "Shake"], id: \.self) { type in
                            Button(type) {
                                mealType = type
                                HapticManager.light()
                            }
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(mealType == type ? Brand.accent : Brand.card)
                            .foregroundColor(mealType == type ? Brand.bg : Brand.textSecondary)
                            .cornerRadius(16)
                        }
                    }
                }

                // Totals — editable
                macroEditRow

                // Detected items
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected Items")
                            .font(.caption)
                            .foregroundColor(Brand.textSecondary)

                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            itemRow(item)
                                .opacity(resultsAppeared ? 1 : 0)
                                .offset(y: resultsAppeared ? 0 : 12)
                                .animation(
                                    .easeOut(duration: 0.35).delay(Double(index) * 0.08),
                                    value: resultsAppeared
                                )
                        }
                    }
                }

                // Notes
                if !notes.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(Brand.textMuted)
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(Brand.textSecondary)
                    }
                    .padding(12)
                    .background(Brand.card)
                    .cornerRadius(10)
                }

                if let err = saveError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(Brand.critical)
                }

                // Save button
                Button {
                    Task { await saveMeal() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(Brand.bg)
                        }
                        Text(isSaving ? "Saving..." : "Save Meal")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(mealName.isEmpty ? Brand.textMuted : Brand.accent)
                    .foregroundColor(Brand.bg)
                    .cornerRadius(12)
                }
                .disabled(mealName.isEmpty || isSaving)

                if let remaining = analysisService.remaining {
                    Text("\(remaining) scans remaining today")
                        .font(.caption2)
                        .foregroundColor(Brand.textMuted)
                }
            }
            .padding()
        }
        .onAppear {
            // Pre-fill from analysis result
            mealName = result.mealName
            calories = "\(result.totals.calories)"
            protein = "\(result.totals.proteinG)"
            carbs = "\(result.totals.carbsG)"
            fat = "\(result.totals.fatG)"
            items = result.items
            confidence = result.confidence
            notes = result.notes ?? ""
            HapticManager.success()
            // Trigger staggered item animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                resultsAppeared = true
            }
        }
    }

    // MARK: - Macro Edit Row

    private var macroEditRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nutrition")
                .font(.caption)
                .foregroundColor(Brand.textSecondary)

            HStack(spacing: 12) {
                macroField("Cal", value: $calories, color: Brand.textPrimary)
                macroField("Protein", value: $protein, color: Brand.accent)
                macroField("Carbs", value: $carbs, color: Brand.secondary)
                macroField("Fat", value: $fat, color: Brand.critical)
            }
        }
    }

    private func macroField(_ label: String, value: Binding<String>, color: Color) -> some View {
        VStack(spacing: 4) {
            TextField("0", text: value)
                .keyboardType(.numberPad)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .padding(8)
                .background(Brand.card)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.textMuted.opacity(0.3), lineWidth: 1))

            Text(label)
                .font(.caption2)
                .foregroundColor(Brand.textSecondary)
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: MealItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Brand.textPrimary)
                Text(item.estimatedPortion)
                    .font(.caption)
                    .foregroundColor(Brand.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.calories) cal")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(Brand.textPrimary)
                Text("P:\(item.proteinG) C:\(item.carbsG) F:\(item.fatG)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Brand.textSecondary)
            }
        }
        .padding(12)
        .background(Brand.card)
        .cornerRadius(10)
    }

    // MARK: - Confidence Badge

    private func confidenceBadge(_ level: String) -> some View {
        let color: Color = switch level {
        case "high": Brand.optimal
        case "medium": Brand.warning
        default: Brand.critical
        }

        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(level.capitalized) confidence")
                .font(.caption.weight(.medium))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Brand.warning)
                .onAppear { HapticManager.error() }

            Text(message)
                .font(.body)
                .foregroundColor(Brand.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Try Again") {
                    analysisService.error = nil
                    capturedImage = nil
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Brand.accent)
                .foregroundColor(Brand.bg)
                .cornerRadius(12)

                Button("Log Manually") {
                    dismiss()
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Brand.card)
                .foregroundColor(Brand.textPrimary)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Save

    private func saveMeal() async {
        isSaving = true
        saveError = nil

        let body: [String: Any] = [
            "meal": mealName,
            "mealType": mealType,
            "date": formatDate(Date()),
            "calories": Int(calories) ?? 0,
            "proteinG": Int(protein) ?? 0,
            "carbsG": Int(carbs) ?? 0,
            "fatG": Int(fat) ?? 0,
            "notes": "[AI Scan] \(confidence) confidence. \(notes)"
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let _: APIResponse<EmptyData> = try await apiService.postRaw("/nutrition", jsonData: jsonData)
            HapticManager.success()
            onSaved?()
            dismiss()
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}

struct EmptyData: Codable, Sendable {}
