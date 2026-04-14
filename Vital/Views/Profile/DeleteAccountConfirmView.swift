import SwiftUI

/// Second-stage confirmation for account deletion. The user has already
/// tapped "Delete Account" and chosen "Continue" in the first confirmation
/// dialog — this view requires them to type DELETE literally before the
/// destructive button becomes active. Matches the double-confirmation
/// pattern used by GitHub, Gmail, and Apple's own Family Sharing removal.
///
/// On success: calls the APIService DELETE /profile endpoint, then signs
/// the user out. ContentView's auth gate routes back to LoginView.
struct DeleteAccountConfirmView: View {
    @Environment(APIService.self) var apiService
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss

    @State private var typedConfirmation: String = ""
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil

    private let confirmationPhrase = "DELETE"

    private var canDelete: Bool {
        typedConfirmation == confirmationPhrase && !isDeleting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Warning icon + headline
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Brand.critical)
                        Text("Permanently Delete Account")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Brand.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("This cannot be undone.")
                            .font(.subheadline)
                            .foregroundColor(Brand.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    // What gets deleted
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The following will be permanently deleted:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Brand.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            bulletRow("Your profile, health conditions, medications, and goals")
                            bulletRow("All Apple Health data synced to Vital (HRV, RHR, sleep, steps, workouts, and more)")
                            bulletRow("All lab results, including flagged and normal-range values")
                            bulletRow("All logged meals, supplements, and water intake")
                            bulletRow("All AI chat conversations and history")
                            bulletRow("Your profile photo")
                            bulletRow("Any connected device tokens (Oura, Whoop, etc.)")
                            bulletRow("Your account itself — you'll no longer be able to sign in with this email")
                        }
                    }
                    .padding(16)
                    .background(Brand.card)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                    // Note about Apple Health
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                        Text("Data in Apple Health itself is not affected. Only the copies Vital has synced to our servers will be deleted.")
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                    }

                    // Confirmation input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To confirm, type DELETE in the box below.")
                            .font(.subheadline)
                            .foregroundColor(Brand.textSecondary)

                        TextField("", text: $typedConfirmation)
                            .textFieldStyle(DarkFieldStyle())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .font(.body.monospaced())
                    }

                    if let error = errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Brand.critical)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Brand.critical)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.critical.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // Destructive action
                    Button(role: .destructive) {
                        Task { await performDelete() }
                    } label: {
                        HStack(spacing: 8) {
                            if isDeleting {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text(isDeleting ? "Deleting..." : "Permanently Delete Account")
                                .font(.body.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canDelete ? Brand.critical : Brand.elevated)
                        .foregroundColor(canDelete ? .white : Brand.textMuted)
                        .cornerRadius(12)
                    }
                    .disabled(!canDelete)
                }
                .padding(20)
            }
            .background(Brand.bg.ignoresSafeArea())
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Brand.accent)
                        .disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline)
                .foregroundColor(Brand.textMuted)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
            Spacer(minLength: 0)
        }
    }

    private func performDelete() async {
        guard canDelete else { return }
        isDeleting = true
        errorMessage = nil
        HapticManager.medium()

        do {
            // DELETE /profile — backend calls supabase.auth.admin.deleteUser(),
            // which cascades across every health table via the FK constraints
            // added in the Session 25 migration. Avatar storage is cleaned up
            // explicitly inside deleteUserAccount() on the server.
            let _: SuccessResponse = try await apiService.delete("/profile")
            HapticManager.success()
            // Sign out locally so the Supabase SDK clears the cached session.
            // ContentView's auth gate will route to LoginView automatically.
            await authService.signOut()
            // No dismiss() needed — signOut flips isSignedIn, ContentView
            // re-renders, and this whole Profile → sheet stack tears down.
        } catch {
            HapticManager.error()
            isDeleting = false
            errorMessage = (error as? APIError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
