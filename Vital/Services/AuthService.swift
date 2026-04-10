import Foundation
import Observation
import Supabase

@MainActor
@Observable class AuthService {
    var isSignedIn = false
    var isLoading = true
    var errorMessage: String?

    let client: SupabaseClient
    private var cachedToken: String?
    private var lastRefreshAt: Date = .distantPast

    init() {
        client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
        Task { await checkSession() }
    }

    func checkSession() async {
        do {
            // Always refresh to get a fresh token — stored session JWT may be expired
            let session = try await client.auth.refreshSession()
            cachedToken = session.accessToken
            lastRefreshAt = Date()
            isSignedIn = true
            print("[AuthService] Refreshed session, token: \(session.accessToken.prefix(20))...")
        } catch {
            print("[AuthService] Refresh failed: \(error). Trying stored session...")
            // Fallback: check if there's a stored session at all
            do {
                _ = try await client.auth.session
                // Session exists but refresh failed — likely expired
                print("[AuthService] Stored session found but expired, need fresh sign-in")
            } catch {
                print("[AuthService] No stored session")
            }
            isSignedIn = false
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            cachedToken = session.accessToken
            lastRefreshAt = Date()
            isSignedIn = true
            print("[AuthService] Sign in success, token: \(session.accessToken.prefix(20))...")
        } catch {
            print("[AuthService] Sign in failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await client.auth.signUp(email: email, password: password)
            cachedToken = session.session?.accessToken
            if session.session != nil { lastRefreshAt = Date() }
            isSignedIn = session.session != nil
            print("[AuthService] Sign up success")
        } catch {
            print("[AuthService] Sign up failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            cachedToken = nil
            lastRefreshAt = .distantPast
            isSignedIn = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func accessToken() async -> String? {
        // Return cached token first
        if let cachedToken {
            print("[AuthService] Using cached token: \(cachedToken.prefix(20))...")
            return cachedToken
        }

        // Fallback: try SDK session
        do {
            let session = try await client.auth.session
            cachedToken = session.accessToken
            return session.accessToken
        } catch {
            print("[AuthService] accessToken() failed: \(error). Attempting refresh...")
            do {
                let refreshed = try await client.auth.refreshSession()
                cachedToken = refreshed.accessToken
                return refreshed.accessToken
            } catch {
                print("[AuthService] refresh also failed: \(error)")
                return nil
            }
        }
    }

    /// Refresh the Supabase session token. Debounced to once per 60s — Supabase
    /// tokens live for ~1 hour, so refreshing more often on every foreground
    /// return is wasted round trips. Callers can force a refresh by passing
    /// `force: true` (e.g. on a 401 retry).
    @discardableResult
    func refreshSession(force: Bool = false) async -> Bool {
        if !force, Date().timeIntervalSince(lastRefreshAt) < 60 {
            return cachedToken != nil
        }
        do {
            let session = try await client.auth.refreshSession()
            cachedToken = session.accessToken
            lastRefreshAt = Date()
            return true
        } catch {
            isSignedIn = false
            cachedToken = nil
            return false
        }
    }
}
