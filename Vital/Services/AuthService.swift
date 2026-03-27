import Foundation
import Supabase

@MainActor
class AuthService: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = true
    @Published var errorMessage: String?

    let client: SupabaseClient

    init() {
        client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
        Task { await checkSession() }
    }

    func checkSession() async {
        do {
            _ = try await client.auth.session
            isSignedIn = true
        } catch {
            isSignedIn = false
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            try await client.auth.signIn(email: email, password: password)
            isSignedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            isSignedIn = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func accessToken() async -> String? {
        do {
            let session = try await client.auth.session
            return session.accessToken
        } catch {
            return nil
        }
    }
}
