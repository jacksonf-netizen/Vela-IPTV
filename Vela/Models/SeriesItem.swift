import Foundation

// MARK: - Series List Item

struct SeriesItem: Identifiable, Codable, Hashable, Equatable {
    let num: Int?
    let name: String
    let seriesId: Int
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let rating: String?
    let categoryId: String?
    var providerId: UUID?

    var id: String { "\(seriesId)_\(providerId?.uuidString ?? "none")" }
    var streamIcon: String? { cover }

    enum CodingKeys: String, CodingKey {
        case num, name, cover, plot, cast, director, genre, rating
        case seriesId = "series_id"
        case releaseDate = "release_date"
        case categoryId = "category_id"
        case providerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        num = try? container.decode(Int.self, forKey: .num)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        if let intId = try? container.decode(Int.self, forKey: .seriesId) {
            seriesId = intId
        } else if let strId = try? container.decode(String.self, forKey: .seriesId),
                  let parsed = Int(strId) {
            seriesId = parsed
        } else {
            seriesId = 0
        }
        cover = try? container.decode(String.self, forKey: .cover)
        plot = try? container.decode(String.self, forKey: .plot)
        cast = try? container.decode(String.self, forKey: .cast)
        director = try? container.decode(String.self, forKey: .director)
        genre = try? container.decode(String.self, forKey: .genre)
        releaseDate = try? container.decode(String.self, forKey: .releaseDate)
        if let ratingStr = try? container.decode(String.self, forKey: .rating) {
            rating = ratingStr.isEmpty ? nil : ratingStr
        } else if let ratingNum = try? container.decode(Double.self, forKey: .rating) {
            rating = ratingNum == 0 ? nil : String(format: "%.1f", ratingNum)
        } else {
            rating = nil
        }
        if let intCat = try? container.decode(Int.self, forKey: .categoryId) {
            categoryId = String(intCat)
        } else {
            categoryId = try? container.decode(String.self, forKey: .categoryId)
        }
        providerId = try? container.decode(UUID.self, forKey: .providerId)
    }

    init(num: Int? = nil, name: String, seriesId: Int, cover: String? = nil, plot: String? = nil,
         cast: String? = nil, director: String? = nil, genre: String? = nil,
         releaseDate: String? = nil, rating: String? = nil, categoryId: String? = nil,
         providerId: UUID? = nil) {
        self.num = num
        self.name = name
        self.seriesId = seriesId
        self.cover = cover
        self.plot = plot
        self.cast = cast
        self.director = director
        self.genre = genre
        self.releaseDate = releaseDate
        self.rating = rating
        self.categoryId = categoryId
        self.providerId = providerId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(num, forKey: .num)
        try container.encode(name, forKey: .name)
        try container.encode(seriesId, forKey: .seriesId)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(plot, forKey: .plot)
        try container.encodeIfPresent(cast, forKey: .cast)
        try container.encodeIfPresent(director, forKey: .director)
        try container.encodeIfPresent(genre, forKey: .genre)
        try container.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(providerId, forKey: .providerId)
    }
}

// MARK: - Series Info Response

struct SeriesInfoResponse: Codable {
    let info: SeriesBasicInfo?
    let seasons: [SeriesSeason]?
    let episodes: [String: [SeriesEpisode]]?
}

struct SeriesBasicInfo: Codable {
    let name: String?
    let cover: String?
    let plot: String?
    let cast: String?
    let genre: String?
    let rating: String?

    enum CodingKeys: String, CodingKey {
        case name, cover, plot, cast, genre, rating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try? container.decode(String.self, forKey: .name)
        cover = try? container.decode(String.self, forKey: .cover)
        plot = try? container.decode(String.self, forKey: .plot)
        cast = try? container.decode(String.self, forKey: .cast)
        genre = try? container.decode(String.self, forKey: .genre)
        if let ratingStr = try? container.decode(String.self, forKey: .rating) {
            rating = ratingStr.isEmpty ? nil : ratingStr
        } else if let ratingNum = try? container.decode(Double.self, forKey: .rating) {
            rating = ratingNum == 0 ? nil : String(format: "%.1f", ratingNum)
        } else {
            rating = nil
        }
    }
}

struct SeriesSeason: Identifiable, Codable, Hashable {
    let id: Int
    let name: String?
    let seasonNumber: Int?
    let cover: String?

    enum CodingKeys: String, CodingKey {
        case id, name, cover
        case seasonNumber = "season_number"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id),
                  let parsed = Int(strId) {
            id = parsed
        } else {
            id = 0
        }
        name = try? container.decode(String.self, forKey: .name)
        if let intSN = try? container.decode(Int.self, forKey: .seasonNumber) {
            seasonNumber = intSN
        } else if let strSN = try? container.decode(String.self, forKey: .seasonNumber),
                  let parsed = Int(strSN) {
            seasonNumber = parsed
        } else {
            seasonNumber = nil
        }
        cover = try? container.decode(String.self, forKey: .cover)
    }
}

struct SeriesEpisode: Identifiable, Codable, Hashable {
    let id: Int
    let episodeNum: Int
    let title: String?
    let containerExtension: String
    let season: Int

    enum CodingKeys: String, CodingKey {
        case id
        case episodeNum = "episode_num"
        case title
        case containerExtension = "container_extension"
        case season
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id),
                  let parsed = Int(strId) {
            id = parsed
        } else {
            id = 0
        }
        if let intEp = try? container.decode(Int.self, forKey: .episodeNum) {
            episodeNum = intEp
        } else if let strEp = try? container.decode(String.self, forKey: .episodeNum),
                  let parsed = Int(strEp) {
            episodeNum = parsed
        } else {
            episodeNum = 0
        }
        title = try? container.decode(String.self, forKey: .title)
        containerExtension = (try? container.decode(String.self, forKey: .containerExtension)) ?? "mkv"
        if let intSeason = try? container.decode(Int.self, forKey: .season) {
            season = intSeason
        } else if let strSeason = try? container.decode(String.self, forKey: .season),
                  let parsed = Int(strSeason) {
            season = parsed
        } else {
            season = 1
        }
    }
}
