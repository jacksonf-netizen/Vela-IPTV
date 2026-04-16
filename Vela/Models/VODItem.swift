import Foundation

struct VODRecentEntry: Identifiable, Codable {
    let id: UUID
    let item: VODItem
    let watchedAt: Date

    init(item: VODItem, watchedAt: Date) {
        self.id = UUID()
        self.item = item
        self.watchedAt = watchedAt
    }
}

struct VODItem: Identifiable, Codable, Hashable, Equatable {
    let num: Int?
    let name: String
    let streamType: String?
    let streamId: Int
    let streamIcon: String?
    let rating: String?
    let added: String?
    let categoryId: String?
    let containerExtension: String?
    var providerId: UUID?

    var id: String { "\(streamId)_\(providerId?.uuidString ?? "none")" }

    enum CodingKeys: String, CodingKey {
        case num
        case name
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case rating = "rating"
        case added
        case categoryId = "category_id"
        case containerExtension = "container_extension"
        case providerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        num = try? container.decode(Int.self, forKey: .num)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        streamType = try? container.decode(String.self, forKey: .streamType)
        if let intId = try? container.decode(Int.self, forKey: .streamId) {
            streamId = intId
        } else if let strId = try? container.decode(String.self, forKey: .streamId),
                  let parsed = Int(strId) {
            streamId = parsed
        } else {
            streamId = 0
        }
        streamIcon = try? container.decode(String.self, forKey: .streamIcon)
        // Rating can come as Double or String
        if let ratingStr = try? container.decode(String.self, forKey: .rating) {
            rating = ratingStr
        } else if let ratingNum = try? container.decode(Double.self, forKey: .rating) {
            rating = String(format: "%.1f", ratingNum)
        } else {
            rating = nil
        }
        added = try? container.decode(String.self, forKey: .added)
        if let intCat = try? container.decode(Int.self, forKey: .categoryId) {
            categoryId = String(intCat)
        } else {
            categoryId = try? container.decode(String.self, forKey: .categoryId)
        }
        containerExtension = try? container.decode(String.self, forKey: .containerExtension)
        providerId = try? container.decode(UUID.self, forKey: .providerId)
    }

    init(num: Int? = nil, name: String, streamType: String? = nil, streamId: Int, streamIcon: String? = nil, rating: String? = nil, added: String? = nil, categoryId: String? = nil, containerExtension: String? = nil, providerId: UUID? = nil) {
        self.num = num
        self.name = name
        self.streamType = streamType
        self.streamId = streamId
        self.streamIcon = streamIcon
        self.rating = rating
        self.added = added
        self.categoryId = categoryId
        self.containerExtension = containerExtension
        self.providerId = providerId
    }
}
