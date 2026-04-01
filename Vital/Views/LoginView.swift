import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) var authService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isSignUp = false

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Brand.accent, Brand.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                        Text("V")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Brand.textPrimary)
                    }
                    Text("Vital")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Brand.textPrimary)
                    Text(isSignUp ? "Create your account" : "Sign in to sync your health data")
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                }

                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(VitalTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(VitalTextFieldStyle())
                        .textContentType(.password)

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Brand.critical)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        isLoading = true
                        Task {
                            if isSignUp {
                                await authService.signUp(email: email, password: password)
                            } else {
                                await authService.signIn(email: email, password: password)
                            }
                            isLoading = false
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Brand.accent)
                        .foregroundColor(Brand.textPrimary)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, 24)

                Button {
                    isSignUp.toggle()
                    authService.errorMessage = nil
                } label: {
                    Text(isSignUp ? "Already have an account? **Sign In**" : "Don't have an account? **Sign Up**")
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                }

                Spacer()
            }
        }
    }
}

struct VitalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(14)
            .background(Brand.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .foregroundColor(Brand.textPrimary)
            .font(.body)
    }
}
