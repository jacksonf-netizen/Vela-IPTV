import Foundation

struct Channel: Identifiable, Codable, Hashable, Equatable {
    let num: Int?
    let name: String
    let streamType: String?
    let streamId: Int
    let streamIcon: String?
    let epgChannelId: String?
    let added: String?
    let categoryId: String?
    let customSid: String?
    let tvArchive: Int?
    let directSource: String?
    let tvArchiveDuration: Int?
    var providerId: UUID? // Tag for multi-provider support

    var id: String { "\(streamId)_\(providerId?.uuidString ?? "none")" }

    enum CodingKeys: String, CodingKey {
        case num
        case name
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelId = "epg_channel_id"
        case added
        case categoryId = "category_id"
        case customSid = "custom_sid"
        case tvArchive = "tv_archive"
        case directSource = "direct_source"
        case tvArchiveDuration = "tv_archive_duration"
        case providerId
    }

    init(num: Int? = nil, name: String, streamType: String? = nil, streamId: Int, streamIcon: String? = nil, epgChannelId: String? = nil, added: String? = nil, categoryId: String? = nil, customSid: String? = nil, tvArchive: Int? = nil, directSource: String? = nil, tvArchiveDuration: Int? = nil, providerId: UUID? = nil) {
        self.num = num
        self.name = name
        self.streamType = streamType
        self.streamId = streamId
        self.streamIcon = streamIcon
        self.epgChannelId = epgChannelId
        self.added = added
        self.categoryId = categoryId
        self.customSid = customSid
        self.tvArchive = tvArchive
        self.directSource = directSource
        self.tvArchiveDuration = tvArchiveDuration
        self.providerId = providerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        num = try? container.decode(Int.self, forKey: .num)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        streamType = try? container.decode(String.self, forKey: .streamType)
        // stream_id can be int or string
        if let intId = try? container.decode(Int.self, forKey: .streamId) {
            streamId = intId
        } else if let strId = try? container.decode(String.self, forKey: .streamId),
                  let parsed = Int(strId) {
            streamId = parsed
        } else {
            streamId = 0
        }
        streamIcon = try? container.decode(String.self, forKey: .streamIcon)
        epgChannelId = try? container.decode(String.self, forKey: .epgChannelId)
        added = try? container.decode(String.self, forKey: .added)
        // category_id can be int or string
        if let intCat = try? container.decode(Int.self, forKey: .categoryId) {
            categoryId = String(intCat)
        } else {
            categoryId = try? container.decode(String.self, forKey: .categoryId)
        }
        customSid = try? container.decode(String.self, forKey: .customSid)
        tvArchive = try? container.decode(Int.self, forKey: .tvArchive)
        directSource = try? container.decode(String.self, forKey: .directSource)
        tvArchiveDuration = try? container.decode(Int.self, forKey: .tvArchiveDuration)
        providerId = try? container.decode(UUID.self, forKey: .providerId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(num, forKey: .num)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(streamType, forKey: .streamType)
        try container.encode(streamId, forKey: .streamId)
        try container.encodeIfPresent(streamIcon, forKey: .streamIcon)
        try container.encodeIfPresent(epgChannelId, forKey: .epgChannelId)
        try container.encodeIfPresent(added, forKey: .added)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(customSid, forKey: .customSid)
        try container.encodeIfPresent(tvArchive, forKey: .tvArchive)
        try container.encodeIfPresent(directSource, forKey: .directSource)
        try container.encodeIfPresent(tvArchiveDuration, forKey: .tvArchiveDuration)
        try container.encodeIfPresent(providerId, forKey: .providerId)
    }
}
