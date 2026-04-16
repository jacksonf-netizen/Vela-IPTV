import Foundation
import Combine

@MainActor
class EPGViewModel: ObservableObject {
    static let shared = EPGViewModel()
    
    @Published var epgDict: [Int: [EPGEntry]] = [:]
    @Published var isFetching: Bool = false
    @Published var lastRefreshed: Date? = nil
    
    private let service = XtreamCodesService.shared
    private var inFlightRequests = Set<Int>()
    private var fetchTask: Task<Void, Never>?
    private var fetchTimestamps: [Int: Date] = [:]  // Track when each channel EPG was last fetched
    private var lastFetchChannels: [Channel] = []
    
    private let staleDuration: TimeInterval = 300   // Entries older than 5m are stale
    
    private init() {
        NotificationCenter.default.addObserver(forName: .velaForceEPGRefresh, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let creds = PersistenceService.shared.activeProvider?.credentials else { return }
                self.clearAndRefresh(for: self.lastFetchChannels, credentials: creds)
            }
        }
    }
    
    /// Fetch EPGs for channels, skipping any that are already cached and fresh.
    func fetchEPG(for channels: [Channel], credentials: XtreamCredentials?, force: Bool = false) {
        guard let creds = credentials else { return }
        self.lastFetchChannels = channels
        
        let now = Date()
        let toFetch = channels.filter { ch in
            if inFlightRequests.contains(ch.streamId) { return false }
            if force { return true }
            // Skip if we have recent data
            if let cached = fetchTimestamps[ch.streamId],
               now.timeIntervalSince(cached) < staleDuration {
                return false
            }
            return true
        }
        guard !toFetch.isEmpty else {
            // Signal completion by pulsing isFetching so the UI transitions to "Cleared!"
            Task { @MainActor in
                self.isFetching = true
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pseudo-delay
                self.isFetching = false
                self.lastRefreshed = Date()
            }
            return 
        }
        
        for ch in toFetch { inFlightRequests.insert(ch.streamId) }
        isFetching = true
        
        fetchTask = Task {
            await withTaskGroup(of: (Int, [EPGEntry]?).self) { group in
                let maxConcurrency = 6
                var index = 0
                
                // Seed initial concurrent requests
                while index < min(maxConcurrency, toFetch.count) {
                    let channel = toFetch[index]
                    group.addTask {
                        var entries: [EPGEntry]? = nil
                        for _ in 0..<3 {
                            if let fetched = try? await self.service.getEPG(credentials: creds, streamId: channel.streamId) {
                                entries = fetched
                                break
                            }
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s backoff before retry
                        }
                        return (channel.streamId, entries)
                    }
                    index += 1
                }
                
                // Add more requests as previous ones finish (backpressure-controlled)
                for await result in group {
                    if Task.isCancelled { break }
                    
                    if let entries = result.1 {
                        self.epgDict[result.0] = entries
                        self.fetchTimestamps[result.0] = Date()
                    }
                    self.inFlightRequests.remove(result.0)
                    
                    if index < toFetch.count {
                        let channel = toFetch[index]
                        group.addTask {
                            var entries: [EPGEntry]? = nil
                            for _ in 0..<3 {
                                if let fetched = try? await self.service.getEPG(credentials: creds, streamId: channel.streamId) {
                                    entries = fetched
                                    break
                                }
                                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s backoff before retry
                            }
                            return (channel.streamId, entries)
                        }
                        index += 1
                    }
                }
            }
            
            for ch in toFetch { inFlightRequests.remove(ch.streamId) }
            isFetching = false
            lastRefreshed = Date()
        }
    }
    
    /// Clear all cached EPG data and force a full re-fetch.
    func clearAndRefresh(for channels: [Channel], credentials: XtreamCredentials?) {
        cancel()
        epgDict.removeAll()
        fetchTimestamps.removeAll()
        fetchEPG(for: channels, credentials: credentials, force: true)
    }
    
    func cancel() {
        fetchTask?.cancel()
        inFlightRequests.removeAll()
        isFetching = false
    }
}
