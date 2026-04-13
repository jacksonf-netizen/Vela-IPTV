import Foundation
import Combine

@MainActor
class ChannelViewModel: ObservableObject {
    @Published var categoriesByProvider: [UUID: [StreamCategory]] = [:]
    @Published var categories: [StreamCategory] = []    // Active categories for current view
    @Published var fullCategories: [StreamCategory] = [] // Master list including hidden ones
    @Published var allChannels: [Channel] = []          // All channels ever loaded
    @Published var categoryChannels: [Channel] = []     // Channels for the active category
    @Published var filteredChannels: [Channel] = []     // Final displayed list (category + search + hidden filter)
    @Published var selectedCategory: StreamCategory? = nil
    @Published var searchQuery: String = ""
    @Published var isLoadingCategories: Bool = false
    @Published var isLoadingChannels: Bool = false
    @Published var errorMessage: String? = nil

    private let service = XtreamCodesService.shared
    private var credentials: XtreamCredentials?
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchQuery
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.rebuildFilteredChannels(query: query)
            }
            .store(in: &cancellables)
            
        // Sync when provider changes — reload the category filter context
        PersistenceService.shared.$activeProviderId
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshHiddenFilter()
            }
            .store(in: &cancellables)

        // Debounce hidden category changes to batch rapid toggles (e.g. "Hide All" in settings)
        PersistenceService.shared.$hiddenCategoryIds
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildFilteredChannels(query: self?.searchQuery ?? "")
            }
            .store(in: &cancellables)
    }

    func setup(credentials: XtreamCredentials) {
        self.credentials = credentials
        // Note: we don't clear allChannels/filteredChannels here anymore to prevent flickering
        // when switching between providers in the sidebar.
    }

    // MARK: - Loading

    func loadCategories(for providerId: UUID, credentials: XtreamCredentials? = nil) async {
        let creds = credentials ?? self.credentials
        guard let creds = creds else { return }
        
        isLoadingCategories = true
        errorMessage = nil
        defer { isLoadingCategories = false }
        
        do {
            let cats = try await service.getLiveCategories(credentials: creds)
            PersistenceService.shared.processIncomingCategories(cats, forProviderId: providerId)
            self.categoriesByProvider[providerId] = cats
            
            // If this is the active provider, update the main lists
            if providerId == PersistenceService.shared.activeProviderId {
                self.fullCategories = cats
                refreshHiddenFilter()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Legacy support or for force-refreshing active provider
    func loadCategories() async {
        if let pid = PersistenceService.shared.activeProviderId {
            await loadCategories(for: pid)
        }
    }

    func selectCategory(_ category: StreamCategory?, providerId: UUID? = nil) async {
        selectedCategory = category
        await loadChannels(categoryId: category?.categoryId, providerId: providerId)
    }

    private func loadChannels(categoryId: String?, providerId: UUID? = nil) async {
        guard let creds = credentials else { return }
        isLoadingChannels = true
        defer { isLoadingChannels = false }
        do {
            let pId = providerId ?? PersistenceService.shared.activeProviderId ?? UUID()
            let channels = try await service.getLiveStreams(credentials: creds, providerId: pId, categoryId: categoryId)
            if categoryId == nil {
                allChannels = channels
            }
            categoryChannels = channels
            rebuildFilteredChannels(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filtering

    /// Single source of truth: always call this to update `filteredChannels`
    private func rebuildFilteredChannels(query: String) {
        let hidden = PersistenceService.shared.hiddenCategoryIds
        let base = categoryChannels.filter { channel in
            guard let catId = channel.categoryId else { return true }
            return !hidden.contains(catId)
        }
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredChannels = base
        } else {
            let q = query.lowercased()
            filteredChannels = base.filter { $0.name.lowercased().contains(q) }
        }
    }

    func refreshHiddenFilter() {
        if let pid = PersistenceService.shared.activeProviderId,
           let cats = categoriesByProvider[pid] {
            self.fullCategories = cats
            let hidden = PersistenceService.shared.hiddenCategoryIds
            categories = cats.filter { !hidden.contains($0.categoryId) }
        }
        rebuildFilteredChannels(query: searchQuery)
    }
}
