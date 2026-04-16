import Foundation
import Combine

@MainActor
class SeriesViewModel: ObservableObject {
    @Published var seriesCategoriesByProvider: [UUID: [StreamCategory]] = [:]
    @Published var seriesItems: [SeriesItem] = []
    @Published var filteredItems: [SeriesItem] = []
    @Published var searchQuery: String = ""
    @Published var filterProviderId: UUID? = nil
    @Published var isLoadingCategories: Bool = false
    @Published var isLoadingItems: Bool = false
    @Published var errorMessage: String? = nil

    private let service = XtreamCodesService.shared
    private var credentials: XtreamCredentials?
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchQuery
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.rebuildFilteredItems(query: query)
            }
            .store(in: &cancellables)

        $filterProviderId
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.rebuildFilteredItems(query: self.searchQuery)
            }
            .store(in: &cancellables)
    }

    func setup(credentials: XtreamCredentials) {
        self.credentials = credentials
    }

    func loadSeriesCategories(for providerId: UUID, credentials: XtreamCredentials) async {
        guard seriesCategoriesByProvider[providerId] == nil else { return }
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        do {
            let cats = try await service.getSeriesCategories(credentials: credentials)
            seriesCategoriesByProvider[providerId] = cats
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectSeriesCategory(_ category: StreamCategory?, providerId: UUID?) async {
        guard let creds = credentials else { return }
        isLoadingItems = true
        defer { isLoadingItems = false }
        do {
            let pId = providerId ?? PersistenceService.shared.activeProviderId ?? UUID()
            let items = try await service.getSeries(credentials: creds, providerId: pId, categoryId: category?.categoryId)
            seriesItems = items
            rebuildFilteredItems(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadAllSeries() async {
        let persistence = PersistenceService.shared
        guard !persistence.providers.isEmpty else { return }
        isLoadingItems = true
        seriesItems = []
        rebuildFilteredItems(query: searchQuery)

        for provider in persistence.providers {
            do {
                let items = try await service.getSeries(
                    credentials: provider.credentials,
                    providerId: provider.id
                )
                seriesItems.append(contentsOf: items)
                rebuildFilteredItems(query: searchQuery)
            } catch {
                // skip provider on error
            }
        }
        isLoadingItems = false
    }

    private func rebuildFilteredItems(query: String) {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        
        filteredItems = seriesItems.filter { item in
            let matchesSearch = q.isEmpty || item.name.lowercased().contains(q)
            let matchesProvider = filterProviderId == nil || item.providerId == filterProviderId
            return matchesSearch && matchesProvider
        }
    }
}
