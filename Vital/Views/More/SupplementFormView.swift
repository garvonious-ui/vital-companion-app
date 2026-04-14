import SwiftUI

struct SupplementFormView: View {
    @Environment(APIService.self) var apiService
    @Environment(\.dismiss) var dismiss

    let supplement: Supplement?
    var onDelete: ((Supplement) -> Void)?

    @State private var name: String = ""
    @State private var type: String = "Supplement"
    @State private var dosage: String = ""
    @State private var frequency: String = "Daily"
    @State private var timing: String = "Morning"
    @State private var status: String = "Active"
    @State private var reason: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private let types = ["Prescription", "Supplement", "OTC"]
    private let timings = ["Morning", "With Meals", "Pre-Workout", "Post-Workout", "Evening", "As Needed"]
    private let statuses = ["Active", "Paused", "Stopped", "Recommended"]

    private var isEditing: Bool { supplement != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        fieldGroup(label: "Name") {
                            TextField("e.g. Vitamin D3", text: $name)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        // Type
                        fieldGroup(label: "Type") {
                            chipPicker(options: types, selected: $type)
                        }

                        // Dosage
                        fieldGroup(label: "Dosage") {
                            TextField("e.g. 500mg, 1 scoop", text: $dosage)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        // Frequency
                        fieldGroup(label: "Frequency") {
                            TextField("e.g. Daily, 2x/day", text: $frequency)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        // Timing
                        fieldGroup(label: "Timing") {
                            chipPicker(options: timings, selected: $timing)
                        }

                        // Status
                        fieldGroup(label: "Status") {
                            chipPicker(options: statuses, selected: $status)
                        }

                        // Reason
                        fieldGroup(label: "Reason (optional)") {
                            TextField("Why are you taking this?", text: $reason)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        // Notes
                        fieldGroup(label: "Notes (optional)") {
                            TextField("Any other notes", text: $notes)
                                .textFieldStyle(DarkFieldStyle())
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Brand.critical)
                        }

                        // Save button
                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isEditing ? "Update" : "Save")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(name.isEmpty ? Brand.textMuted : Brand.accent)
                            .cornerRadius(12)
                        }
                        .disabled(name.isEmpty || isSaving)

                        // Delete button (edit mode only)
                        if isEditing, let supp = supplement {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Supplement")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundColor(Brand.critical)
                            }
                            .confirmationDialog("Delete \(supp.name)?", isPresented: $showDeleteConfirm) {
                                Button("Delete", role: .destructive) {
                                    onDelete?(supp)
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }
                    .padding(16)
                }
                .dismissKeyboardOnDrag()
            }
            .navigationTitle(isEditing ? "Edit Supplement" : "Add Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardToolbarDone()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.accent)
                }
            }
            .onAppear {
                if let s = supplement {
                    name = s.name
                    type = s.type ?? "Supplement"
                    dosage = s.dosage ?? ""
                    frequency = s.frequency ?? "Daily"
                    timing = s.timing ?? "Morning"
                    status = s.status ?? "Active"
                    reason = s.reason ?? ""
                    notes = s.notes ?? ""
                }
            }
        }
    }

    // MARK: - Field Group

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(Brand.textMuted)
            content()
        }
    }

    // MARK: - Chip Picker

    private func chipPicker(options: [String], selected: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selected.wrappedValue = option
                    } label: {
                        Text(option)
                            .font(.caption.weight(.medium))
                            .foregroundColor(selected.wrappedValue == option ? .white : Brand.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selected.wrappedValue == option
                                    ? Brand.accent.opacity(0.3)
                                    : Brand.elevated
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selected.wrappedValue == option
                                            ? Brand.accent.opacity(0.5)
                                            : Color.white.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil

        let body: [String: String] = {
            var b: [String: String] = [
                "name": name,
                "type": type,
                "dosage": dosage,
                "frequency": frequency,
                "timing": timing,
                "status": status,
            ]
            if !reason.isEmpty { b["reason"] = reason }
            if !notes.isEmpty { b["notes"] = notes }
            if let s = supplement { b["id"] = s.id }
            return b
        }()

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            if isEditing {
                let _: SuccessResponse = try await apiService.patchRaw("/supplements", jsonData: jsonData)
            } else {
                let _: SuccessResponse = try await apiService.postRaw("/supplements", jsonData: jsonData)
            }
            HapticManager.success()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
}
