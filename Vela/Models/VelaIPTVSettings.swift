import Foundation

// MARK: - Settings Enums
enum DefaultTab: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case liveTV = "Live TV"
    case movies = "Movies & TV"
}

enum StartupScreen: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case recents = "Recently Watched"
    case favorites = "Favorites"
}

enum FontSizeScale: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case small = "Small"
    case normal = "Normal"
    case large = "Large"
}

enum UpdateInterval: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case never = "Manual only"
    case everyLaunch = "Update on app start"
    case twelveHours = "Every 12 hours"
    case daily = "Daily"
}

enum ClickAction: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case playFullscreen = "Play Fullscreen"
    case showInfo = "Show Info Panel"
}

enum KeyAction: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case changeChannel = "Change Channel / Scroll"
    case volume = "Adjust Volume"
    case showPlayer = "Show Player"
    case toggleFullscreen = "Toggle Fullscreen"
    case openEPG = "Open TV Guide"
    case none = "Do Nothing"
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

// MARK: - Config Struct
struct VelaIPTVSettings: Codable, Equatable {
    // 1. General
    var startupScreen: StartupScreen = .recents
    
    // 2. Appearance
    var fontSize: FontSizeScale = .normal
    var showLogos: Bool = true
    var themeMode: ThemeMode = .dark
    
    // 3. Playlists (Accounts)
    var autoUpdatePlaylists: UpdateInterval = .everyLaunch
    
    // 4. TV Guide
    var epgUpdateInterval: UpdateInterval = .daily
    var epgHistoryDays: Int = 1
    var timelineHourScale: Double = 300.0 // px per hour
    
    // 5. Playback
    var autoFrameRate: Bool = false
    var defaultClickAction: ClickAction = .playFullscreen
    var hardwareDecoding: Bool = true
    
    // 6. Keys
    var upDownAction: KeyAction = .changeChannel
    var leftRightAction: KeyAction = .volume
    var enterAction: KeyAction = .toggleFullscreen

    // 7. Content
    var showVOD: Bool = true
    var defaultTab: DefaultTab = .liveTV
    
    static let `default` = VelaIPTVSettings()
}
