import Foundation
import Observation

@MainActor
@Observable class APIService {
    let authService: AuthService
    private let session = URLSession.shared

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO 8601 with fractional seconds first
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }

            // Try without fractional seconds
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }

            // Try date-only (YYYY-MM-DD)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.locale = Locale(identifier: "en_US_POSIX")
            if let date = df.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Public API

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try await buildRequest(path: path, method: "GET", queryItems: queryItems)
        return try await execute(request)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try await buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try await buildRequest(path: path, method: "PATCH")
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    func delete<T: Decodable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try await buildRequest(path: path, method: "DELETE", queryItems: queryItems)
        return try await execute(request)
    }

    func patchRaw<T: Decodable>(_ path: String, jsonData: Data) async throws -> T {
        var request = try await buildRequest(path: path, method: "PATCH")
        request.httpBody = jsonData
        return try await execute(request)
    }

    /// POST with raw JSON data (for dynamic payloads that don't fit a static Codable struct)
    func postRaw<T: Decodable>(_ path: String, jsonData: Data) async throws -> T {
        var request = try await buildRequest(path: path, method: "POST")
        request.httpBody = jsonData
        return try await execute(request)
    }

    /// POST that returns raw bytes for SSE streaming
    func postStream(_ path: String, body: some Encodable) async throws -> (URLSession.AsyncBytes, URLResponse) {
        var request = try await buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        return try await session.bytes(for: request)
    }

    // MARK: - Private

    private func buildRequest(path: String, method: String, queryItems: [URLQueryItem]? = nil) async throws -> URLRequest {
        guard let token = await authService.accessToken() else {
            throw APIError.unauthorized
        }

        var components = URLComponents(url: Config.apiBaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest, retried: Bool = false) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw APIError.offline
            case .timedOut:
                throw APIError.timeout
            case .secureConnectionFailed, .serverCertificateUntrusted:
                throw APIError.sslError
            default:
                throw APIError.networkError(urlError.localizedDescription)
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 && !retried {
            // Try refreshing the session and retrying once
            print("[APIService] Got 401, attempting token refresh...")
            let refreshed = await authService.refreshSession()
            if refreshed {
                let newRequest = try await buildRequest(
                    path: request.url!.path.replacingOccurrences(of: "/api", with: ""),
                    method: request.httpMethod ?? "GET"
                )
                return try await execute(newRequest, retried: true)
            }
            throw APIError.unauthorized
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(statusCode: http.statusCode, body: body)
        }

        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case unauthorized
    case invalidURL
    case invalidResponse
    case offline
    case timeout
    case sslError
    case networkError(String)
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please sign in again."
        case .invalidURL: return "Invalid request URL."
        case .invalidResponse: return "Invalid response from server."
        case .offline: return "You're offline. Check your connection and try again."
        case .timeout: return "Request timed out. Try again."
        case .sslError: return "Secure connection failed. Try again in a moment."
        case .networkError(let msg): return "Network error: \(msg)"
        case .serverError(let code, _): return "Server error (\(code))."
        }
    }

    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }
}
