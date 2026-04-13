import Foundation
import Combine
import Sparkle
import SwiftUI

class PersistenceService: ObservableObject {
    static let shared = PersistenceService()

    private let providersKey      = "velaiptv.providers"
    private let activeProviderKey  = "velaiptv.activeProviderId"
    private let favoritesKey       = "velaiptv.favorites"
    private let recentsKey         = "velaiptv.recents"
    private let hiddenCatsKey      = "velaiptv.hiddenCategories" // Legacy global key
    private let perProviderCatsKey = "velaiptv.perProviderHiddenCategories"
    private let playbackBufferKey  = "velaiptv.playbackBufferDuration"
    private let bufferProfileKey   = "velaiptv.bufferProfile"
    private let startupDelayKey    = "velaiptv.startupBufferDelay"
    private let streamFormatKey    = "velaiptv.preferredStreamFormat"
    private let secretsPrefix      = "velaiptv.provider.secure."
    private let maxRecents         = 20
    private let maxProviders       = 5
    
    // Coalesced save work items — prevent rapid UserDefaults writes from blocking main thread
    private var favoriteSaveWork: DispatchWorkItem?
    private var recentsSaveWork: DispatchWorkItem?
    private var hiddenCatsSaveWork: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.velaiptv.persistence.save", qos: .utility)
    
    // Obfuscation key - just to deter casual inspection
    private let obfuscationKey: [UInt8] = [0x56, 0x65, 0x6C, 0x61, 0x49, 0x50, 0x54, 0x56] // "VelaIPTV"

    @Published var providers: [Provider] = []
    @Published var activeProviderId: UUID? = nil
    @Published var favorites: [Channel] = []
    @Published var recents: [RecentEntry] = []
    @Published var hiddenCategoryIds: Set<String> = [] // The active set
    
    // Precomputed lookup sets for O(1) checks instead of O(n) array iteration
    private(set) var favoriteIds: Set<String> = []
    private(set) var favoriteStreamIds: Set<Int> = [] // For legacy orphan matching
    @Published var allHiddenCategories: [String: Set<String>] = [:] // ProviderID -> CategoryIDs (Set for O(1) lookup)
    @Published var playbackBufferDuration: Double = 15.0 // Default 15s matching user preference
    @Published var bufferProfile: BufferProfile = .medium
    @Published var startupBufferDelay: Double = 0.0 // Default 0s for fastest start
    @Published var preferredStreamFormat: StreamFormat = .hls
    
    @Published var autoHideNewCategories: Bool = false
    private let autoHideCatsKey = "velaiptv.settings.autoHideNewCats"
    
    @Published var settings: VelaIPTVSettings = .default {
        didSet {
            saveSettingsSync()
        }
    }
    private let settingsKey = "velaiptv.settings.master"
    
    private var knownCategories: [String: Set<String>] = [:]
    private let knownCatsKey = "velaiptv.settings.knownCats"

    var activeProvider: Provider? {
        providers.first { $0.id == activeProviderId } ?? providers.first
    }

    private init() {
        loadProviders()
        loadFavorites()
        loadRecents()
        loadHiddenCategories()
        loadAutoHideNewCategories()
        loadKnownCategories()
        loadSettings()
        loadBufferProfile()
        loadPlaybackBuffer()
        loadStartupDelay()
        loadStreamFormat()
        
        // Rebuild lookup sets from loaded data
        rebuildFavoriteSets()
        
        // Heal asynchronously to avoid blocking app launch
        DispatchQueue.main.async { [weak self] in
            self?.healAll()
        }
    }

    func healAll() {
        favorites = deduplicate(healChannels(favorites))
        recents = deduplicateRecentEntries(healRecentEntries(recents))
        rebuildFavoriteSets()
        saveFavoritesCoalesced()
        saveRecentsCoalesced()
    }
    
    /// Rebuild O(1) lookup sets from the favorites array
    private func rebuildFavoriteSets() {
        favoriteIds = Set(favorites.map { $0.id })
        favoriteStreamIds = Set(favorites.filter { $0.providerId == nil }.map { $0.streamId })
    }

    private func deduplicate(_ channels: [Channel]) -> [Channel] {
        var unique: [Channel] = []
        var seenIds: Set<String> = []
        for channel in channels {
            if !seenIds.contains(channel.id) {
                unique.append(channel)
                seenIds.insert(channel.id)
            }
        }
        return unique
    }

    private func deduplicateRecentEntries(_ entries: [RecentEntry]) -> [RecentEntry] {
        var unique: [RecentEntry] = []
        var seenIds: Set<String> = []
        for entry in entries {
            if !seenIds.contains(entry.channel.id) {
                unique.append(entry)
                seenIds.insert(entry.channel.id)
            }
        }
        return unique
    }

    // MARK: – Auto-Hide & Known Categories Tracking & Global Settings

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(VelaIPTVSettings.self, from: data) {
            settings = decoded
        }
    }
    
    private func saveSettingsSync() {
        if let encoded = try? JSONEncoder().encode(settings) {
            saveQueue.async {
                UserDefaults.standard.set(encoded, forKey: self.settingsKey)
            }
        }
    }

    private func loadAutoHideNewCategories() {
        autoHideNewCategories = UserDefaults.standard.bool(forKey: autoHideCatsKey)
    }

    func setAutoHideNewCategories(_ val: Bool) {
        autoHideNewCategories = val
        UserDefaults.standard.set(val, forKey: autoHideCatsKey)
    }
    
    private func loadKnownCategories() {
        if let data = UserDefaults.standard.dictionary(forKey: knownCatsKey) as? [String: [String]] {
            knownCategories = data.mapValues { Set($0) }
        }
    }
    
    private func saveKnownCategoriesSync() {
        let serializable = knownCategories.mapValues { Array($0) }
        let key = knownCatsKey
        let work = DispatchWorkItem {
            UserDefaults.standard.set(serializable, forKey: key)
        }
        saveQueue.async(execute: work)
    }

    func processIncomingCategories(_ cats: [StreamCategory], forProviderId pid: UUID) {
        let incomingIds = Set(cats.map { $0.categoryId })
        let idKey = pid.uuidString
        let previouslyKnown = knownCategories[idKey]
        
        // Auto-hide master "All" categories to prevent landing on cluttered lists
        let allCategoryPatterns = ["all", "all channels", "toute", "tout", "everything", "all tv"]
        let idsToAutoHide = Set(cats.filter { cat in
            let name = cat.categoryName.lowercased()
            return allCategoryPatterns.contains { pattern in
                name == pattern || name.contains(pattern)
            }
        }.map { $0.categoryId })

        if previouslyKnown == nil {
            // First time seeing this provider's categories
            knownCategories[idKey] = incomingIds
            saveKnownCategoriesSync()
            
            // Hide "All" categories immediately
            if !idsToAutoHide.isEmpty {
                var hidden = allHiddenCategories[idKey] ?? []
                hidden.formUnion(idsToAutoHide)
                allHiddenCategories[idKey] = hidden
                if activeProviderId == pid { hiddenCategoryIds = hidden }
                saveHiddenCategoriesSync()
            }
        } else if let prev = previouslyKnown {
            let newIds = incomingIds.subtracting(prev)
            if !newIds.isEmpty {
                // Update known
                knownCategories[idKey] = prev.union(newIds)
                saveKnownCategoriesSync()
                
                // If auto-hide is enabled, hide the new ones
                var hidden = allHiddenCategories[idKey] ?? []
                if autoHideNewCategories {
                    hidden.formUnion(newIds)
                }
                
                // Always ensure newly appeared "All" categories are hidden
                hidden.formUnion(idsToAutoHide)
                
                allHiddenCategories[idKey] = hidden
                if activeProviderId == pid { hiddenCategoryIds = hidden }
                saveHiddenCategoriesSync()
            }
        }
    }

    // MARK: – Providers

    func addProvider(_ provider: Provider) {
        guard providers.count < maxProviders else {
            #if DEBUG
            print("[Vela IPTV] WARNING: Max provider limit reached (5). Cannot add more.")
            #endif
            return
        }
        providers.append(provider)
        if activeProviderId == nil { activeProviderId = provider.id }
        saveProviders()
    }

    func removeProvider(_ provider: Provider) {
        providers.removeAll { $0.id == provider.id }
        // Remove locally stored secrets
        UserDefaults.standard.removeObject(forKey: secretsPrefix + provider.id.uuidString)
        // Cleanup keychain if it exists (silent fallback)
        deleteFromKeychain(account: "velaiptv.provider.\(provider.id.uuidString)")
        
        if activeProviderId == provider.id {
            activeProviderId = providers.first?.id
        }
        saveProviders()
    }
    
    func logout() {
        activeProviderId = nil
    }

    func setActiveProvider(_ provider: Provider) {
        activeProviderId = provider.id
        UserDefaults.standard.set(provider.id.uuidString, forKey: activeProviderKey)
        // Switch hidden categories context
        updateActiveHiddenCategories()
    }

    func updateProvider(_ provider: Provider) {
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = provider
            saveProviders()
        }
    }

    private func saveProviders() {
        // Save non-secret provider metadata to UserDefaults
        let metaOnly = providers.map { p in
            ["id": p.id.uuidString, "name": p.name]
        }
        UserDefaults.standard.set(metaOnly, forKey: providersKey)
        
        // Save secrets locally with obfuscation
        for p in providers {
            let key = secretsPrefix + p.id.uuidString
            let secrets: [String: String] = [
                "serverURL": p.serverURL,
                "username": p.username,
                "password": p.password
            ]
            
            if let data = try? JSONEncoder().encode(secrets) {
                let obfuscated = obfuscate(data)
                UserDefaults.standard.set(obfuscated.base64EncodedString(), forKey: key)
            }
        }
        
        if let id = activeProviderId {
            UserDefaults.standard.set(id.uuidString, forKey: activeProviderKey)
        }
    }

    private func obfuscate(_ data: Data) -> Data {
        var result = Data()
        for i in 0..<data.count {
            result.append(data[i] ^ obfuscationKey[i % obfuscationKey.count])
        }
        return result
    }

    // MARK: - Keychain Migration Helpers (Permissionless)

    private func loadFromKeychain(account: String) -> String? {
        let service = "com.velaiptv.app.iptv-credentials"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func deleteFromKeychain(account: String) {
        let service = "com.velaiptv.app.iptv-credentials"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func loadProviders() {
        // Load metadata from UserDefaults, then secrets from Keychain
        if let meta = UserDefaults.standard.array(forKey: providersKey) as? [[String: String]] {
            providers = meta.compactMap { dict -> Provider? in
                guard let idStr = dict["id"],
                      let id = UUID(uuidString: idStr),
                      let name = dict["name"] else { return nil }
                
                // 1. Try new local obfuscated storage
                let localKey = secretsPrefix + idStr
                if let base64 = UserDefaults.standard.string(forKey: localKey),
                   let data = Data(base64Encoded: base64) {
                    let deobfuscated = obfuscate(data)
                    if let secrets = try? JSONDecoder().decode([String: String].self, from: deobfuscated) {
                        return Provider(
                            id: id,
                            name: name,
                            serverURL: secrets["serverURL"] ?? "",
                            username: secrets["username"] ?? "",
                            password: secrets["password"] ?? ""
                        )
                    }
                }
                
                // 2. Fallback to Keychain migration
                let keychainKey = "velaiptv.provider.\(idStr)"
                if let json = loadFromKeychain(account: keychainKey),
                   let data = json.data(using: .utf8),
                   let secrets = try? JSONDecoder().decode([String: String].self, from: data) {
                    
                    let p = Provider(
                        id: id,
                        name: name,
                        serverURL: secrets["serverURL"] ?? "",
                        username: secrets["username"] ?? "",
                        password: secrets["password"] ?? ""
                    )
                    
                    // Immediately migrate to new format
                    let newSecretKey = secretsPrefix + idStr
                    let secretsDict: [String: String] = [
                        "serverURL": p.serverURL,
                        "username": p.username,
                        "password": p.password
                    ]
                    if let sData = try? JSONEncoder().encode(secretsDict) {
                        let obfuscated = obfuscate(sData)
                        UserDefaults.standard.set(obfuscated.base64EncodedString(), forKey: newSecretKey)
                        // Note: We don't delete from keychain immediately to be safe, 
                        // but it will never be checked again if local storage exists.
                    }
                    
                    return p
                }
                
                return nil
            }
        }

        if let idStr = UserDefaults.standard.string(forKey: activeProviderKey),
           let id = UUID(uuidString: idStr) {
            activeProviderId = id
        } else {
            activeProviderId = providers.first?.id
        }

        // Migrate from very old single-credentials format if needed
        if providers.isEmpty {
            let oldKey = "streamio.credentials"
            if let data = UserDefaults.standard.data(forKey: oldKey),
               let creds = try? JSONDecoder().decode(XtreamCredentials.self, from: data) {
                let migrated = Provider(name: "My Provider", serverURL: creds.serverURL, username: creds.username, password: creds.password)
                providers = [migrated]
                activeProviderId = migrated.id
                saveProviders()
                UserDefaults.standard.removeObject(forKey: oldKey)
            }
        }
    }

    // MARK: – Hidden Categories

    func isCategoryHidden(_ categoryId: String, providerId: UUID? = nil) -> Bool {
        if let pid = providerId {
            return allHiddenCategories[pid.uuidString]?.contains(categoryId) ?? false
        }
        return hiddenCategoryIds.contains(categoryId)
    }

    func toggleCategoryHidden(_ categoryId: String, forProviderId pid: UUID? = nil) {
        let providerId = pid ?? activeProviderId
        guard let providerId = providerId else { return }
        
        var hidden = allHiddenCategories[providerId.uuidString] ?? []
        if hidden.contains(categoryId) {
            hidden.remove(categoryId)
        } else {
            hidden.insert(categoryId)
        }
        allHiddenCategories[providerId.uuidString] = hidden
        
        // Synchronize current set if we're editing the active provider
        if providerId == activeProviderId {
            hiddenCategoryIds = hidden
        }
        
        saveHiddenCategoriesSync()
    }

    func setCategoriesHidden(_ categoryIds: Set<String>, forProviderId pid: UUID? = nil) {
        let providerId = pid ?? activeProviderId
        guard let providerId = providerId else { return }
        
        allHiddenCategories[providerId.uuidString] = categoryIds
        
        if providerId == activeProviderId {
            hiddenCategoryIds = categoryIds
        }
        
        saveHiddenCategoriesSync()
    }

    private func saveHiddenCategoriesSync() {
        hiddenCatsSaveWork?.cancel()
        // Snapshot Sets → Arrays for UserDefaults serialization
        let serializable = allHiddenCategories.mapValues { Array($0) }
        let key = perProviderCatsKey
        let work = DispatchWorkItem {
            UserDefaults.standard.set(serializable, forKey: key)
        }
        hiddenCatsSaveWork = work
        saveQueue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func saveHiddenCategories() {
        if let id = activeProviderId?.uuidString {
            allHiddenCategories[id] = hiddenCategoryIds
        }
        saveHiddenCategoriesSync()
    }

    private func loadHiddenCategories() {
        // 1. Try to load per-provider settings (deserialize Arrays → Sets)
        if let data = UserDefaults.standard.dictionary(forKey: perProviderCatsKey) as? [String: [String]] {
            allHiddenCategories = data.mapValues { Set($0) }
        }
        
        // 2. Migration: If we have old global hidden categories and no per-provider data yet, assign to current
        let legacy = UserDefaults.standard.stringArray(forKey: hiddenCatsKey) ?? []
        if !legacy.isEmpty && allHiddenCategories.isEmpty {
            if let id = activeProviderId?.uuidString {
                allHiddenCategories[id] = Set(legacy)
                UserDefaults.standard.removeObject(forKey: hiddenCatsKey)
            }
        }
        
        updateActiveHiddenCategories()
    }

    private func updateActiveHiddenCategories() {
        if let id = activeProviderId?.uuidString {
            hiddenCategoryIds = allHiddenCategories[id] ?? []
        } else {
            hiddenCategoryIds = []
        }
    }

    // PHASE 18: Regional Visibility
    func isRegionVisible(_ regionName: String, in cats: [StreamCategory], forProviderId pid: UUID? = nil) -> Bool {
        // A region is "visible" if at least one of its categories is NOT hidden
        cats.contains { !isCategoryHidden($0.categoryId, providerId: pid) }
    }

    func toggleRegionVisibility(_ regionName: String, in cats: [StreamCategory], forProviderId pid: UUID? = nil) {
        let providerId = pid ?? activeProviderId
        guard let providerId = providerId else { return }

        var hidden = allHiddenCategories[providerId.uuidString] ?? []
        let anyVisible = cats.contains { !hidden.contains($0.categoryId) }
        
        if anyVisible {
            // Hide all in region
            for cat in cats { hidden.insert(cat.categoryId) }
        } else {
            // Show all in region
            for cat in cats { hidden.remove(cat.categoryId) }
        }
        
        allHiddenCategories[providerId.uuidString] = hidden
        
        if providerId == activeProviderId {
            hiddenCategoryIds = hidden
        }
        
        saveHiddenCategoriesSync()
    }

    // MARK: – Favorites

    func isFavorite(_ channel: Channel) -> Bool {
        // O(1) lookup via precomputed sets
        if favoriteIds.contains(channel.id) { return true }
        // Legacy orphan matching
        return favoriteStreamIds.contains(channel.streamId)
    }

    func toggleFavorite(_ channel: Channel) {
        var channelToSave = channel
        
        // 1. If we find an exact ID match, we are definitely un-saving it
        if let exactIndex = favorites.firstIndex(where: { $0.id == channel.id }) {
            favorites.remove(at: exactIndex)
            rebuildFavoriteSets()
            saveFavoritesCoalesced()
            return
        }
        
        // 2. If we find a legacy orphan match (nil providerId), we'll remove it 
        // regardless of whether we have a providerId in the incoming channel.
        if let orphanIndex = favorites.firstIndex(where: { $0.streamId == channel.streamId && $0.providerId == nil }) {
            favorites.remove(at: orphanIndex)
            rebuildFavoriteSets()
            saveFavoritesCoalesced()
            return
        }
        
        // 3. Otherwise we are adding a new favorite - ensure it has a providerId
        if channelToSave.providerId == nil {
            channelToSave.providerId = activeProviderId
        }
        favorites.append(channelToSave)
        rebuildFavoriteSets()
        saveFavoritesCoalesced()
    }

    /// Coalesced save — batches rapid toggles into a single write after 300ms of quiet
    private func saveFavoritesCoalesced() {
        favoriteSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.saveFavoritesImmediate()
        }
        favoriteSaveWork = work
        saveQueue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    
    private func saveFavoritesImmediate() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: favoritesKey)
        } catch {
            #if DEBUG
            print("[Vela IPTV] ERROR: Failed to save favorites: \(error)")
            #endif
        }
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode([Channel].self, from: data)
        else { return }
        favorites = healChannels(decoded)
    }

    private func healChannels(_ channels: [Channel]) -> [Channel] {
        var healed = channels
        // If only one provider exists, we can safely heal any nil providerIds
        if providers.count == 1, let uniqueId = providers.first?.id {
            for i in 0..<healed.count {
                if healed[i].providerId == nil {
                    healed[i].providerId = uniqueId
                }
            }
        }
        return healed
    }
    
    private func healRecentEntries(_ entries: [RecentEntry]) -> [RecentEntry] {
        var healed = entries
        if providers.count == 1, let uniqueId = providers.first?.id {
            for i in 0..<healed.count {
                if healed[i].channel.providerId == nil {
                    // RecentEntry has a let channel, so we need to recreate it if we heal
                    let oldChannel = healed[i].channel
                    var newChannel = oldChannel
                    newChannel.providerId = uniqueId
                    healed[i] = RecentEntry(channel: newChannel, watchedAt: healed[i].watchedAt)
                }
            }
        }
        return healed
    }

    // MARK: – Recents

    func addRecent(_ channel: Channel) {
        var channelToSave = channel
        if channelToSave.providerId == nil {
            channelToSave.providerId = activeProviderId
        }
        
        recents.removeAll { $0.channel.id == channelToSave.id }
        recents.insert(RecentEntry(channel: channelToSave, watchedAt: Date()), at: 0)
        if recents.count > maxRecents { recents = Array(recents.prefix(maxRecents)) }
        saveRecentsCoalesced()
    }

    func removeRecent(_ entry: RecentEntry) {
        recents.removeAll { $0.id == entry.id }
        saveRecentsCoalesced()
    }

    func clearRecents() {
        recents = []
        saveRecentsCoalesced()
    }

    /// Coalesced save — batches rapid updates into a single write after 300ms of quiet
    private func saveRecentsCoalesced() {
        recentsSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.saveRecentsImmediate()
        }
        recentsSaveWork = work
        saveQueue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    
    private func saveRecentsImmediate() {
        do {
            let data = try JSONEncoder().encode(recents)
            UserDefaults.standard.set(data, forKey: recentsKey)
        } catch {
            #if DEBUG
            print("[Vela IPTV] ERROR: Failed to save recents: \(error)")
            #endif
        }
    }

    private func loadRecents() {
        guard let data = UserDefaults.standard.data(forKey: recentsKey),
              let decoded = try? JSONDecoder().decode([RecentEntry].self, from: data)
        else { return }
        recents = healRecentEntries(decoded)
    }

    // MARK: – Settings

    func setPlaybackBufferDuration(_ duration: Double) {
        playbackBufferDuration = duration
        UserDefaults.standard.set(duration, forKey: playbackBufferKey)
    }

    func setBufferProfile(_ profile: BufferProfile) {
        bufferProfile = profile
        playbackBufferDuration = profile.duration
        UserDefaults.standard.set(profile.rawValue, forKey: bufferProfileKey)
        UserDefaults.standard.set(playbackBufferDuration, forKey: playbackBufferKey)
    }

    func setStartupBufferDelay(_ delay: Double) {
        startupBufferDelay = delay
        UserDefaults.standard.set(delay, forKey: startupDelayKey)
    }

    func setStreamFormat(_ format: StreamFormat) {
        preferredStreamFormat = format
        UserDefaults.standard.set(format.rawValue, forKey: streamFormatKey)
    }

    private func loadPlaybackBuffer() {
        if UserDefaults.standard.object(forKey: playbackBufferKey) != nil {
            playbackBufferDuration = UserDefaults.standard.double(forKey: playbackBufferKey)
        } else {
            playbackBufferDuration = bufferProfile.duration
        }
    }

    private func loadBufferProfile() {
        if let raw = UserDefaults.standard.string(forKey: bufferProfileKey),
           let profile = BufferProfile(rawValue: raw) {
            bufferProfile = profile
        }
    }

    private func loadStartupDelay() {
        if UserDefaults.standard.object(forKey: startupDelayKey) != nil {
            startupBufferDelay = UserDefaults.standard.double(forKey: startupDelayKey)
        }
    }

    private func loadStreamFormat() {
        if let raw = UserDefaults.standard.string(forKey: streamFormatKey),
           let format = StreamFormat(rawValue: raw) {
            preferredStreamFormat = format
        }
    }
}

enum StreamFormat: String, CaseIterable {
    case hls = "HLS"
    case ts = "MPEG-TS"
    
    var extensionName: String {
        switch self {
        case .hls: return "m3u8"
        case .ts: return "ts"
        }
    }
}

struct RecentEntry: Identifiable, Codable {
    let id: UUID
    let channel: Channel
    let watchedAt: Date

    init(channel: Channel, watchedAt: Date) {
        self.id = UUID()
        self.channel = channel
        self.watchedAt = watchedAt
    }
}

enum BufferProfile: String, CaseIterable {
    case none = "None"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case veryLarge = "Very Large"
    
    var duration: Double {
        switch self {
        case .none: return 0
        case .small: return 5
        case .medium: return 15
        case .large: return 30
        case .veryLarge: return 60
        }
    }
    
    var description: String {
        switch self {
        case .none: return "Instant start, requires perfect connection"
        case .small: return "5s buffer, balanced speed"
        case .medium: return "15s buffer, industry standard"
        case .large: return "30s buffer, high stability"
        case .veryLarge: return "60s buffer, for problematic providers"
        }
    }
}

// MARK: – Software Update ViewModel
/// Manages the application update lifecycle using the Sparkle framework.
final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        // Initialize the standard updater controller.
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }
}

