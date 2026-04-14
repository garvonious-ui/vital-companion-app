import SwiftUI

struct OnboardingView: View {
    @Environment(APIService.self) var apiService
    @Environment(AuthService.self) var authService
    @State private var step = 0
    @State private var isSaving = false
    @State private var error: String?

    // Step 1: Basics
    @State private var displayName = ""
    @State private var sex = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date())!

    // Step 2: Body
    @State private var heightFt = "5"
    @State private var heightIn = "10"
    @State private var weight = ""
    @State private var goals: [String] = []

    // Step 3: Targets
    @State private var caloriesTarget = "2000"
    @State private var proteinTarget = "150"
    @State private var stepsTarget = "8000"
    @State private var waterTarget = "80"

    @Binding var isComplete: Bool

    private let goalOptions = ["Body Recomp", "Weight Loss", "Muscle Gain", "Better Sleep", "Lower Cholesterol", "General Health", "Stress Management", "Athletic Performance"]
    private let sexOptions = ["Male", "Female", "Other"]

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 4) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i <= step ? Brand.accent : Brand.elevated)
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Step content
                TabView(selection: $step) {
                    step1Basics.tag(0)
                    step2Body.tag(1)
                    step3Targets.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: step)

                // Bottom button
                VStack(spacing: 12) {
                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Brand.critical)
                    }

                    Button {
                        if step < 2 {
                            step += 1
                            HapticManager.light()
                        } else {
                            Task { await save() }
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(Brand.bg)
                            }
                            Text(step < 2 ? "Continue" : "Get Started")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Brand.accent)
                        .foregroundColor(Brand.bg)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving || (step == 0 && displayName.isEmpty))
                    .opacity(step == 0 && displayName.isEmpty ? 0.5 : 1)

                    if step > 0 {
                        Button("Back") {
                            step -= 1
                        }
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .keyboardToolbarDone()
    }

    // MARK: - Step 1: Basics

    private var step1Basics: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepHeader("Welcome to Vital", subtitle: "Let's set up your profile so we can personalize your experience.")

                fieldLabel("What should we call you?")
                TextField("First name", text: $displayName)
                    .textFieldStyle(VitalTextFieldStyle())

                fieldLabel("Sex")
                HStack(spacing: 10) {
                    ForEach(sexOptions, id: \.self) { option in
                        Button(option) {
                            sex = option
                            HapticManager.light()
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(sex == option ? Brand.accent : Brand.card)
                        .foregroundColor(sex == option ? Brand.bg : Brand.textSecondary)
                        .cornerRadius(10)
                    }
                }

                fieldLabel("Date of Birth")
                DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
            .padding(24)
        }
        .dismissKeyboardOnDrag()
    }

    // MARK: - Step 2: Body + Goals

    private var step2Body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepHeader("Your Body", subtitle: "This helps us estimate calories and track progress.")

                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        fieldLabel("Height (ft)")
                        TextField("5", text: $heightFt)
                            .textFieldStyle(VitalTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    VStack(alignment: .leading) {
                        fieldLabel("Height (in)")
                        TextField("10", text: $heightIn)
                            .textFieldStyle(VitalTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                }

                VStack(alignment: .leading) {
                    fieldLabel("Weight (lbs)")
                    TextField("170", text: $weight)
                        .textFieldStyle(VitalTextFieldStyle())
                        .keyboardType(.numberPad)
                }

                fieldLabel("Goals (select all that apply)")
                FlowLayout(spacing: 8) {
                    ForEach(goalOptions, id: \.self) { goal in
                        Button(goal) {
                            if goals.contains(goal) {
                                goals.removeAll { $0 == goal }
                            } else {
                                goals.append(goal)
                            }
                            HapticManager.light()
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(goals.contains(goal) ? Brand.accent : Brand.card)
                        .foregroundColor(goals.contains(goal) ? Brand.bg : Brand.textSecondary)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(24)
        }
        .dismissKeyboardOnDrag()
    }

    // MARK: - Step 3: Daily Targets

    private var step3Targets: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepHeader("Daily Targets", subtitle: "Set your goals — you can always change these later in Settings.")

                targetRow(label: "Calories", value: $caloriesTarget, unit: "cal/day", icon: "flame.fill", color: Brand.warning)
                targetRow(label: "Protein", value: $proteinTarget, unit: "g/day", icon: "fish.fill", color: Brand.accent)
                targetRow(label: "Steps", value: $stepsTarget, unit: "steps/day", icon: "figure.walk", color: Brand.optimal)
                targetRow(label: "Water", value: $waterTarget, unit: "oz/day", icon: "drop.fill", color: Brand.accent)
            }
            .padding(24)
        }
        .dismissKeyboardOnDrag()
    }

    // MARK: - Helpers

    private func stepHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(Brand.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
        }
        .padding(.bottom, 8)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundColor(Brand.textSecondary)
    }

    private func targetRow(label: String, value: Binding<String>, unit: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Brand.textPrimary)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }

            Spacer()

            TextField("0", text: value)
                .keyboardType(.numberPad)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(Brand.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(8)
                .background(Brand.card)
                .cornerRadius(8)
        }
        .padding(14)
        .background(Brand.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        error = nil

        let heightInches: Int? = {
            guard let ft = Int(heightFt), let inches = Int(heightIn) else { return nil }
            return ft * 12 + inches
        }()

        let profileBody: [String: Any] = [
            "displayName": displayName,
            "sex": sex,
            "dateOfBirth": formatDate(dateOfBirth),
            "heightInches": heightInches as Any,
            "weightLbs": Int(weight) as Any,
            "goals": goals,
        ]

        let targetsBody: [String: Any] = [
            "caloriesMin": max(Int(caloriesTarget) ?? 2000 - 200, 1200),
            "caloriesMax": (Int(caloriesTarget) ?? 2000) + 200,
            "proteinMin": max((Int(proteinTarget) ?? 150) - 20, 50),
            "proteinMax": (Int(proteinTarget) ?? 150) + 20,
            "steps": Int(stepsTarget) ?? 8000,
            "waterOz": Int(waterTarget) ?? 80,
        ]

        do {
            let profileData = try JSONSerialization.data(withJSONObject: profileBody)
            let _: APIResponse<EmptyData> = try await apiService.postRaw("/profile", jsonData: profileData)

            let targetsData = try JSONSerialization.data(withJSONObject: targetsBody)
            let _: APIResponse<EmptyData> = try await apiService.postRaw("/targets", jsonData: targetsData)

            HapticManager.success()
            isComplete = true
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
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

// FlowLayout is defined in ProfileView.swift
