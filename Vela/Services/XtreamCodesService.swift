import Foundation

enum XtreamError: LocalizedError {
    case invalidURL
    case authFailed(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL. Please check your server address."
        case .authFailed(let msg): return "Authentication failed: \(msg)"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .decodingError(let e): return "Data error: \(e.localizedDescription)"
        }
    }
}

actor XtreamCodesService {
    static let shared = XtreamCodesService()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        self.session = URLSession(configuration: config)
    }

    // MARK: – Auth

    func authenticate(credentials: XtreamCredentials) async throws -> AuthResponse {
        guard !credentials.baseURL.isEmpty else { throw XtreamError.invalidURL }
        // Use URLComponents to prevent URL injection from special chars in credentials
        var components = URLComponents(string: "\(credentials.baseURL)/player_api.php")
        components?.queryItems = [
            URLQueryItem(name: "username", value: credentials.username),
            URLQueryItem(name: "password", value: credentials.password)
        ]
        guard let authURL = components?.url else { throw XtreamError.invalidURL }
        do {
            let (data, response) = try await session.data(from: authURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw XtreamError.authFailed("Server returned an error response.")
            }
            let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
            if let status = decoded.userInfo?.status, status == "Active" || status == "active" || status == "Expired" {
                return decoded
            } else if decoded.userInfo != nil {
                return decoded
            } else {
                throw XtreamError.authFailed("Invalid credentials or server not reachable.")
            }
        } catch let e as XtreamError {
            throw e
        } catch _ as DecodingError {
            throw XtreamError.authFailed("Server responded but isn't a valid Xtream Codes panel.")
        } catch {
            throw XtreamError.networkError(error)
        }
    }

    // MARK: – Live TV

    func getLiveCategories(credentials: XtreamCredentials) async throws -> [StreamCategory] {
        guard let url = credentials.playerAPIURL(action: "get_live_categories") else {
            throw XtreamError.invalidURL
        }
        return try await fetch([StreamCategory].self, from: url)
    }

    func getLiveStreams(credentials: XtreamCredentials, providerId: UUID, categoryId: String? = nil) async throws -> [Channel] {
        var params: [String: String] = [:]
        if let catId = categoryId { params["category_id"] = catId }
        guard let url = credentials.playerAPIURL(action: "get_live_streams", params: params) else {
            throw XtreamError.invalidURL
        }
        var channels = try await fetch([Channel].self, from: url)
        for i in 0..<channels.count {
            channels[i].providerId = providerId
        }
        return channels
    }

    func getEPG(credentials: XtreamCredentials, streamId: Int) async throws -> [EPGEntry] {
        guard let url = credentials.playerAPIURL(action: "get_short_epg", params: [
            "stream_id": String(streamId),
            "limit": "5"
        ]) else {
            throw XtreamError.invalidURL
        }
        let response = try await fetch(EPGResponse.self, from: url)
        return response.epgListings ?? []
    }

    // MARK: – Private

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        // Reject non-HTTP(S) schemes to prevent SSRF from malformed provider URLs
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw XtreamError.invalidURL
        }
        return try await fetchWithRetry(type, from: url, retries: 1)
    }

    private func fetchWithRetry<T: Decodable>(_ type: T.Type, from url: URL, retries: Int) async throws -> T {
        do {
            let (data, response) = try await session.data(from: url)
            // Validate HTTP status before attempting decode
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw XtreamError.networkError(NSError(
                    domain: "XtreamCodesService",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(http.statusCode)"]
                ))
            }
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch let e as XtreamError {
            throw e
        } catch let e as DecodingError {
            throw XtreamError.decodingError(e)
        } catch {
            // Retry once on transient network failures
            if retries > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                return try await fetchWithRetry(type, from: url, retries: retries - 1)
            }
            throw XtreamError.networkError(error)
        }
    }
}
