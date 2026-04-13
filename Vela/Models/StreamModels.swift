import Foundation

struct StreamCategory: Identifiable, Codable, Hashable {
    let categoryId: String
    let categoryName: String
    let parentId: Int?

    var id: String { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case parentId = "parent_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .categoryId) {
            categoryId = String(intId)
        } else {
            categoryId = (try? container.decode(String.self, forKey: .categoryId)) ?? "0"
        }
        categoryName = (try? container.decode(String.self, forKey: .categoryName)) ?? "Unknown"
        parentId = try? container.decode(Int.self, forKey: .parentId)
    }
}

struct UserInfo: Codable {
    let username: String?
    let password: String?
    let status: String?
    let expDate: String?
    let isTrial: String?
    let activeCons: String?
    let maxConnections: String?

    enum CodingKeys: String, CodingKey {
        case username, password, status
        case expDate = "exp_date"
        case isTrial = "is_trial"
        case activeCons = "active_cons"
        case maxConnections = "max_connections"
    }
}

struct AuthResponse: Codable {
    let userInfo: UserInfo?

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
    }
}

struct EPGEntry: Identifiable, Codable {
    let id: String
    let epgId: String?
    let title: String
    let lang: String?
    let start: String
    let end: String
    let description: String?
    let channelId: String?
    let startTimestamp: String?
    let stopTimestamp: String?

    enum CodingKeys: String, CodingKey {
        case id, lang, start, end, description
        case epgId = "epg_id"
        case title = "title"
        case channelId = "channel_id"
        case startTimestamp = "start_timestamp"
        case stopTimestamp = "stop_timestamp"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        epgId = try? container.decode(String.self, forKey: .epgId)
        // title is base64 encoded in Xtream Codes
        let rawTitle = (try? container.decode(String.self, forKey: .title)) ?? ""
        if let data = Data(base64Encoded: rawTitle),
           let decoded = String(data: data, encoding: .utf8) {
            title = decoded
        } else {
            title = rawTitle
        }
        lang = try? container.decode(String.self, forKey: .lang)
        start = (try? container.decode(String.self, forKey: .start)) ?? ""
        end = (try? container.decode(String.self, forKey: .end)) ?? ""
        let rawDesc = (try? container.decode(String.self, forKey: .description)) ?? ""
        if let data = Data(base64Encoded: rawDesc),
           let decoded = String(data: data, encoding: .utf8) {
            description = decoded
        } else {
            description = rawDesc.isEmpty ? nil : rawDesc
        }
        channelId = try? container.decode(String.self, forKey: .channelId)
        startTimestamp = try? container.decode(String.self, forKey: .startTimestamp)
        stopTimestamp = try? container.decode(String.self, forKey: .stopTimestamp)
    }
}

struct EPGResponse: Codable {
    let epgListings: [EPGEntry]?

    enum CodingKeys: String, CodingKey {
        case epgListings = "epg_listings"
    }
}
