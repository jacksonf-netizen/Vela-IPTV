import Foundation

struct XtreamCredentials: Codable, Equatable {
    var serverURL: String
    var username: String
    var password: String

    var baseURL: String {
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        return url
    }

    func playerAPIURL(action: String, params: [String: String] = [:]) -> URL? {
        var components = URLComponents(string: "\(baseURL)/player_api.php")
        var queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: action)
        ]
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    func streamURL(for channel: Channel, format: StreamFormat = .hls) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.path = "/live/\(username)/\(password)/\(channel.streamId).\(format.extensionName)"
        return components?.url
    }
}

// MARK: - Provider (multi-provider support)

struct Provider: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String          // User-given label e.g. "Sports Bundle"
    var serverURL: String
    var username: String
    var password: String

    init(id: UUID = UUID(), name: String, serverURL: String, username: String, password: String) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }

    var credentials: XtreamCredentials {
        XtreamCredentials(serverURL: serverURL, username: username, password: password)
    }
}
