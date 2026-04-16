import SwiftUI
import Combine

struct MoviesView: View {
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var vodVM: VODViewModel
    @ObservedObject var seriesVM: SeriesViewModel
    @ObservedObject private var persistence = PersistenceService.shared
    @State private var selectedCategory: VODSidebarSelection = .recents
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @State private var selectedItem: VODItem? = nil
    @State private var selectedSeries: SeriesItem? = nil
    let onPlayItem: (VODItem) -> Void
    let onPlayEpisode: (SeriesEpisode, SeriesItem) -> Void

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VODSidebarView(
                vodVM: vodVM,
                seriesVM: seriesVM,
                selectedCategory: $selectedCategory
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            ZStack {
                switch selectedCategory {
                case .recents:
                    VODRecentsView(onSelect: { item in selectedItem = item })
                case .favorites:
                    VODFavoritesView(onSelect: { item in selectedItem = item })
                case .allMovies:
                    VODGridView(
                        items: vodVM.filteredItems,
                        searchQuery: $vodVM.searchQuery,
                        filterProviderId: $vodVM.filterProviderId,
                        isLoading: vodVM.isLoadingItems,
                        sectionTitle: "All Movies",
                        onSelect: { item in selectedItem = item }
                    )
                case .search:
                    VODSearchView(vodVM: vodVM, onSelect: { item in selectedItem = item })
                case .category(let cat, _):
                    VODGridView(
                        items: vodVM.filteredItems,
                        searchQuery: $vodVM.searchQuery,
                        filterProviderId: $vodVM.filterProviderId,
                        isLoading: vodVM.isLoadingItems,
                        sectionTitle: cat.categoryName,
                        onSelect: { item in selectedItem = item }
                    )
                case .allSeries:
                    SeriesGridView(
                        items: seriesVM.filteredItems,
                        searchQuery: $seriesVM.searchQuery,
                        filterProviderId: $seriesVM.filterProviderId,
                        isLoading: seriesVM.isLoadingItems,
                        sectionTitle: "All Series",
                        onSelect: { series in selectedSeries = series }
                    )
                case .searchSeries:
                    SeriesSearchView(seriesVM: seriesVM, onSelect: { series in selectedSeries = series })
                case .seriesCategory(let cat, _):
                    SeriesGridView(
                        items: seriesVM.filteredItems,
                        searchQuery: $seriesVM.searchQuery,
                        filterProviderId: $seriesVM.filterProviderId,
                        isLoading: seriesVM.isLoadingItems,
                        sectionTitle: cat.categoryName,
                        onSelect: { series in selectedSeries = series }
                    )
                }
            }
        }
        .navigationTitle("")
        .onChange(of: selectedCategory) { _, newCategory in
            handleCategoryChange(newCategory)
        }
        .sheet(item: $selectedItem) { item in
            VODDetailSheet(item: item, onPlay: { vodItem in
                selectedItem = nil
                onPlayItem(vodItem)
            })
        }
        .sheet(item: $selectedSeries) { series in
            SeriesDetailSheet(series: series, onPlayEpisode: { episode in
                selectedSeries = nil
                onPlayEpisode(episode, series)
            })
        }
    }

    private func handleCategoryChange(_ category: VODSidebarSelection) {
        switch category {
        case .allMovies:
            Task { await vodVM.loadAllMovies() }
        case .allSeries:
            Task { await seriesVM.loadAllSeries() }
        case .recents, .favorites, .search, .searchSeries:
            break
        case .category(let cat, let providerId):
            if let provider = persistence.providers.first(where: { $0.id == providerId }) {
                if persistence.activeProviderId != providerId {
                    persistence.setActiveProvider(provider)
                }
                Task {
                    vodVM.setup(credentials: provider.credentials)
                    await vodVM.selectVODCategory(cat, providerId: providerId)
                }
            }
        case .seriesCategory(let cat, let providerId):
            if let provider = persistence.providers.first(where: { $0.id == providerId }) {
                if persistence.activeProviderId != providerId {
                    persistence.setActiveProvider(provider)
                }
                Task {
                    seriesVM.setup(credentials: provider.credentials)
                    await seriesVM.selectSeriesCategory(cat, providerId: providerId)
                }
            }
        }
    }
}

// MARK: - Series Grid View

struct SeriesGridView: View {
    let items: [SeriesItem]
    @Binding var searchQuery: String
    @Binding var filterProviderId: UUID?
    let isLoading: Bool
    let sectionTitle: String
    let onSelect: (SeriesItem) -> Void
    @ObservedObject private var persistence = PersistenceService.shared

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sectionTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("\(items.count) shows")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)

                        TextField("Search shows…", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: 240)

                        if !searchQuery.isEmpty {
                            Button { searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                    Menu {
                        Button {
                            filterProviderId = nil
                        } label: {
                            HStack {
                                Text("All Providers")
                                if filterProviderId == nil { Image(systemName: "checkmark") }
                            }
                        }

                        ForEach(persistence.providers) { provider in
                            Button {
                                filterProviderId = provider.id
                            } label: {
                                HStack {
                                    Text(provider.name)
                                    if filterProviderId == provider.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: filterProviderId == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(filterProviderId == nil ? Color.appTextSecondary : Color.appAccent)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 2)
            .padding(.bottom, 4)

            if isLoading && items.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    VelaIPTVSpinner(size: 44, lineWidth: 4)
                    Text("Fetching Shows…")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
            } else if !isLoading && items.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "tv",
                    title: "No shows found",
                    subtitle: searchQuery.isEmpty ? "This category is currently empty." : "Try adjusting your search."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(items) { series in
                            SeriesCardView(series: series, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    .padding(.bottom, isLoading ? 16 : 32)

                    if isLoading {
                        HStack(spacing: 12) {
                            VelaIPTVSpinner(size: 20, lineWidth: 2)
                            Text("Loading more…")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(.bottom, 32)
                    }
                }
                .scrollClipDisabled()
                .frame(minHeight: 0, idealHeight: 100, maxHeight: .infinity)
            }
        }
        .background(Color.clear)
    }
}

// MARK: - Series Card View

struct SeriesCardView: View {
    let series: SeriesItem
    let onSelect: (SeriesItem) -> Void
    @State private var isHovering = false

    var body: some View {
        Button { onSelect(series) } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: isHovering ? Color.appAccent.opacity(0.2) : .black.opacity(0.2), radius: isHovering ? 15 : 8, x: 0, y: isHovering ? 10 : 4)

                    IsolatedSeriesPoster(coverUrl: series.cover, name: series.name)

                    if let rating = series.rating, !rating.isEmpty, rating != "0", rating != "0.0" {
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.yellow)
                                    Text(rating)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                        .mask(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                )
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                .padding(8)
                            }
                            Spacer()
                        }
                    }

                    if isHovering {
                        ZStack {
                            VisualEffectView(material: .selection, blendingMode: .withinWindow)
                                .opacity(0.4)
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(series.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isHovering)
    }
}

// MARK: - Series Placeholder

struct SeriesPlaceholder: View {
    let name: String
    var body: some View {
        ZStack {
            Color.appSurface
            Text(name.prefix(1).uppercased())
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(Color.appAccent.opacity(0.4))
            Image(systemName: "tv")
                .font(.system(size: 20))
                .foregroundColor(Color.appAccent.opacity(0.2))
                .offset(y: 30)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Series Search View

struct SeriesSearchView: View {
    @ObservedObject var seriesVM: SeriesViewModel
    @ObservedObject private var persistence = PersistenceService.shared
    @StateObject private var vm = SeriesSearchViewModel()
    let onSelect: (SeriesItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search TV Shows")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Find series across all providers")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    Spacer()
                }

                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.appTextSecondary)

                            TextField("Search for shows...", text: $vm.searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)

                            if !vm.searchQuery.isEmpty {
                                Button { vm.searchQuery = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.appTextSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )

                        Menu {
                            Button {
                                vm.filterProviderId = nil
                            } label: {
                                HStack {
                                    Text("All Providers")
                                    if vm.filterProviderId == nil { Image(systemName: "checkmark") }
                                }
                            }

                            ForEach(persistence.providers) { provider in
                                Button {
                                    vm.filterProviderId = provider.id
                                } label: {
                                    HStack {
                                        Text(provider.name)
                                        if vm.filterProviderId == provider.id { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: vm.filterProviderId == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(vm.filterProviderId == nil ? Color.appTextSecondary : Color.appAccent)
                                .frame(width: 42, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
            }
            .padding(.horizontal, 32)
            .padding(.top, 2)
            .padding(.bottom, 6)

            if vm.isSearching {
                Spacer()
                VStack(spacing: 16) {
                    VelaIPTVSpinner(size: 44, lineWidth: 4)
                    Text("Searching…")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
            } else if vm.searchQuery.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "tv",
                    title: "Search TV Shows",
                    subtitle: "Start typing to search across all your providers."
                )
                Spacer()
            } else if vm.searchResults.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "tv",
                    title: "No Results",
                    subtitle: "No shows found matching \"\(vm.searchQuery)\"."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(vm.searchResults) { series in
                            SeriesCardView(series: series, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollClipDisabled()
                .frame(minHeight: 0, idealHeight: 100, maxHeight: .infinity)
            }
        }
    }
}

@MainActor
class SeriesSearchViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var filterProviderId: UUID? = nil
    @Published var searchResults: [SeriesItem] = []
    @Published var isSearching: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var allSeriesCache: [SeriesItem]? = nil

    init() {
        $searchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { [weak self] in await self?.performSearch(query: query) }
            }
            .store(in: &cancellables)

        $filterProviderId
            .sink { [weak self] _ in
                Task { [weak self] in guard let self = self else { return }
                    await self.performSearch(query: self.searchQuery)
                }
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Use cache if available, but always filter by provider if set
        if let cached = allSeriesCache {
            searchResults = cached.filter { item in
                let matchesSearch = q.isEmpty || item.name.lowercased().contains(q)
                let matchesProvider = filterProviderId == nil || item.providerId == filterProviderId
                return matchesSearch && matchesProvider
            }
            return
        }

        if q.isEmpty {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        var allItems: [SeriesItem] = []
        for provider in PersistenceService.shared.providers {
            do {
                let items = try await XtreamCodesService.shared.getSeries(
                    credentials: provider.credentials,
                    providerId: provider.id
                )
                allItems.append(contentsOf: items)
            } catch { }
        }
        allSeriesCache = allItems
        searchResults = allItems.filter { item in
            let matchesSearch = item.name.lowercased().contains(q)
            let matchesProvider = filterProviderId == nil || item.providerId == filterProviderId
            return matchesSearch && matchesProvider
        }
    }
}

// MARK: - Series Detail Sheet

struct SeriesDetailSheet: View, Identifiable {
    let series: SeriesItem
    let onPlayEpisode: (SeriesEpisode) -> Void
    var id: String { series.id }

    @State private var seriesInfo: SeriesInfoResponse? = nil
    @State private var isLoading = true
    @State private var selectedSeason: Int = 1
    @Environment(\.dismiss) private var dismiss

    var sortedSeasonNumbers: [Int] {
        (seriesInfo?.episodes ?? [:]).keys.compactMap { Int($0) }.sorted()
    }

    var currentEpisodes: [SeriesEpisode] {
        (seriesInfo?.episodes?[String(selectedSeason)] ?? []).sorted { $0.episodeNum < $1.episodeNum }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.appTextSecondary)
                }
                .buttonStyle(.plain)
                .padding(16)
            }

            if isLoading {
                Spacer()
                VelaIPTVSpinner(size: 44, lineWidth: 4)
                Spacer()
            } else {
                HStack(alignment: .top, spacing: 28) {
                    // Poster
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.appSurface)

                        if let coverUrl = series.cover, let url = URL(string: coverUrl) {
                            AsyncImage(url: url) { phase in
                                if case .success(let image) = phase {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .padding(12)
                                } else {
                                    SeriesPlaceholder(name: series.name)
                                }
                            }
                        } else {
                            SeriesPlaceholder(name: series.name)
                        }
                    }
                    .frame(width: 180, height: 260)
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

                    // Info + episodes
                    VStack(alignment: .leading, spacing: 12) {
                        Text(series.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            if let rating = series.rating, !rating.isEmpty, rating != "0", rating != "0.0" {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow)
                                    Text(rating)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }

                            if let genre = series.genre, !genre.isEmpty {
                                Text(genre)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color.appAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.appAccent.opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            ProviderBadge(providerId: series.providerId)
                        }

                        // Season picker
                        if sortedSeasonNumbers.count > 1 {
                            ScrollView(.horizontal, showsIndicators: true) {
                                HStack(spacing: 6) {
                                    ForEach(sortedSeasonNumbers, id: \.self) { num in
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                selectedSeason = num
                                            }
                                        } label: {
                                            Text("Season \(num)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(selectedSeason == num ? .white : Color.appTextSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(selectedSeason == num ? Color.appAccent : Color.white.opacity(0.06))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        } else if let onlySeason = sortedSeasonNumbers.first {
                            Text("Season \(onlySeason)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color.appTextSecondary)
                        }

                        // Episodes
                        if currentEpisodes.isEmpty {
                            Spacer()
                            Text("No episodes available")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                            Spacer()
                        } else {
                            ScrollView {
                                VStack(spacing: 6) {
                                    ForEach(currentEpisodes) { episode in
                                        EpisodeRow(episode: episode, onPlay: { onPlayEpisode(episode) })
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 720, height: 500)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay(Color.black.opacity(0.3))
        )
        .task {
            await loadSeriesInfo()
        }
    }

    private func loadSeriesInfo() async {
        defer { isLoading = false }
        guard let provider = PersistenceService.shared.providers.first(where: { $0.id == series.providerId }) else { return }
        do {
            let info = try await XtreamCodesService.shared.getSeriesInfo(credentials: provider.credentials, seriesId: series.seriesId)
            seriesInfo = info
            if let first = info.episodes?.keys.compactMap({ Int($0) }).sorted().first {
                selectedSeason = first
            }
        } catch {
            // show whatever we have (empty state)
        }
    }
}

// MARK: - Episode Row

struct EpisodeRow: View {
    let episode: SeriesEpisode
    let onPlay: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                // Episode number badge
                Text("E\(episode.episodeNum)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.appAccent.opacity(isHovering ? 0.9 : 0.6))
                    )

                Text(episode.title?.isEmpty == false ? episode.title! : "Episode \(episode.episodeNum)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isHovering ? .white : Color.appTextPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isHovering ? .white : Color.appTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)
    }
}

// MARK: - VOD Recents View

struct VODRecentsView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    let onSelect: (VODItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recently Watched")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(persistence.vodRecents.count) movies")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer(minLength: 8)
                if !persistence.vodRecents.isEmpty {
                    Button { persistence.clearVODRecents() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .bold))
                            Text("Clear History")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.appLiveRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appLiveRed.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 2)
            .padding(.bottom, 4)

            if persistence.vodRecents.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Nothing watched yet",
                    subtitle: "Movies you watch will appear here for quick access."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(persistence.vodRecents) { entry in
                            VODRecentCard(entry: entry, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollClipDisabled()
            }
        }
        .background(Color.clear)
    }
}

// MARK: - VOD Recent Card

struct VODRecentCard: View {
    let entry: VODRecentEntry
    let onSelect: (VODItem) -> Void
    @State private var isHovering = false

    var timeAgoString: String {
        let diff = Date().timeIntervalSince(entry.watchedAt)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }

    var body: some View {
        Button { onSelect(entry.item) } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: isHovering ? Color.appAccent.opacity(0.2) : .black.opacity(0.2), radius: isHovering ? 15 : 8, x: 0, y: isHovering ? 10 : 4)

                    IsolatedVODPoster(streamIcon: entry.item.streamIcon, name: entry.item.name)

                    VStack {
                        HStack {
                            Spacer()
                            Text(timeAgoString)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                        .mask(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                )
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                .padding(8)
                        }
                        Spacer()
                    }

                    if isHovering {
                        ZStack {
                            VisualEffectView(material: .selection, blendingMode: .withinWindow)
                                .opacity(0.4)
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(entry.item.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isHovering)
        .contextMenu {
            Button { onSelect(entry.item) } label: {
                Label("Play Movie", systemImage: "play.fill")
            }
            Divider()
            Button(role: .destructive) {
                PersistenceService.shared.removeVODRecent(entry)
            } label: {
                Label("Remove from Recents", systemImage: "xmark.circle")
            }
        }
    }
}

// MARK: - VOD Favorites View

struct VODFavoritesView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    let onSelect: (VODItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorites")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(persistence.vodFavorites.count) saved movies")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 32)
            .padding(.top, 2)
            .padding(.bottom, 4)

            if persistence.vodFavorites.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "heart.slash.fill",
                    title: "No favorites yet",
                    subtitle: "Press \"Love It\" in the movie detail to save your favorites here."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(persistence.vodFavorites) { item in
                            VODPosterCard(item: item, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollClipDisabled()
            }
        }
        .background(Color.clear)
    }
}

// MARK: - VOD Search View

struct VODSearchView: View {
    @ObservedObject var vodVM: VODViewModel
    @ObservedObject private var persistence = PersistenceService.shared
    @StateObject private var vm = VODSearchViewModel()
    let onSelect: (VODItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search Movies")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Find movies across all providers")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    Spacer()
                }

                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.appTextSecondary)

                            TextField("Search for movies...", text: $vm.searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)

                            if !vm.searchQuery.isEmpty {
                                Button { vm.searchQuery = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.appTextSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )

                        Menu {
                            Button {
                                vm.filterProviderId = nil
                            } label: {
                                HStack {
                                    Text("All Providers")
                                    if vm.filterProviderId == nil { Image(systemName: "checkmark") }
                                }
                            }

                            ForEach(persistence.providers) { provider in
                                Button {
                                    vm.filterProviderId = provider.id
                                } label: {
                                    HStack {
                                        Text(provider.name)
                                        if vm.filterProviderId == provider.id { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: vm.filterProviderId == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(vm.filterProviderId == nil ? Color.appTextSecondary : Color.appAccent)
                                .frame(width: 42, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
            }
            .padding(.horizontal, 32)
            .padding(.top, 2)
            .padding(.bottom, 6)

            if vm.isSearching {
                Spacer()
                VStack(spacing: 16) {
                    VelaIPTVSpinner(size: 44, lineWidth: 4)
                    Text("Searching…")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
            } else if vm.searchQuery.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Search Movies",
                    subtitle: "Start typing to search across all your providers."
                )
                Spacer()
            } else if vm.searchResults.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "film.fill",
                    title: "No Results",
                    subtitle: "No movies found matching \"\(vm.searchQuery)\"."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(vm.searchResults) { item in
                            VODPosterCard(item: item, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollClipDisabled()
                .frame(minHeight: 0, idealHeight: 100, maxHeight: .infinity)
            }
        }
    }
}

@MainActor
class VODSearchViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var filterProviderId: UUID? = nil
    @Published var searchResults: [VODItem] = []
    @Published var isSearching: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var allVODCache: [VODItem]? = nil

    init() {
        $searchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { [weak self] in await self?.performSearch(query: query) }
            }
            .store(in: &cancellables)

        $filterProviderId
            .sink { [weak self] _ in
                Task { [weak self] in guard let self = self else { return }
                    await self.performSearch(query: self.searchQuery)
                }
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Use cache if available, but always filter by provider if set
        if let cached = allVODCache {
            searchResults = cached.filter { item in
                let matchesSearch = q.isEmpty || item.name.lowercased().contains(q)
                let matchesProvider = filterProviderId == nil || item.providerId == filterProviderId
                return matchesSearch && matchesProvider
            }
            return
        }

        if q.isEmpty {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        var allItems: [VODItem] = []
        for provider in PersistenceService.shared.providers {
            do {
                let items = try await XtreamCodesService.shared.getVODStreams(
                    credentials: provider.credentials,
                    providerId: provider.id
                )
                allItems.append(contentsOf: items)
            } catch { }
        }
        allVODCache = allItems
        searchResults = allItems.filter { item in
            let matchesSearch = item.name.lowercased().contains(q)
            let matchesProvider = filterProviderId == nil || item.providerId == filterProviderId
            return matchesSearch && matchesProvider
        }
    }
}

// MARK: - VOD Detail Sheet

struct VODDetailSheet: View, Identifiable {
    let item: VODItem
    let onPlay: (VODItem) -> Void
    var id: String { item.id }

    @ObservedObject private var persistence = PersistenceService.shared
    @State private var isHoveringPlay = false
    @State private var isHoveringFavorite = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.appTextSecondary)
                }
                .buttonStyle(.plain)
                .padding(16)
            }

            HStack(alignment: .top, spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appSurface)

                    if let iconUrl = item.streamIcon, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(16)
                            } else {
                                VODPlaceholder(name: item.name)
                            }
                        }
                    } else {
                        VODPlaceholder(name: item.name)
                    }
                }
                .frame(width: 200, height: 280)
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 16) {
                    Text(item.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 16) {
                        if let rating = item.rating, !rating.isEmpty, rating != "0", rating != "0.0" {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                Text(rating)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }

                        if let ext = item.containerExtension {
                            Text(ext.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.appAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.appAccent.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        ProviderBadge(providerId: item.providerId)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button { onPlay(item) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16))
                                Text("Play Movie")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.appAccent)
                                    .shadow(color: Color.appAccent.opacity(isHoveringPlay ? 0.5 : 0.3), radius: isHoveringPlay ? 16 : 8, x: 0, y: 4)
                            )
                            .scaleEffect(isHoveringPlay ? 1.03 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringPlay = $0 }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringPlay)

                        let isFav = persistence.isVODFavorite(item)
                        Button { persistence.toggleVODFavorite(item) } label: {
                            HStack(spacing: 7) {
                                Image(systemName: isFav ? "heart.fill" : "heart")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(isFav ? "Loved" : "Love It")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(isFav ? .pink : Color.appTextSecondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isFav ? Color.pink.opacity(0.15) : Color.white.opacity(0.08))
                            )
                            .scaleEffect(isHoveringFavorite ? 1.03 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringFavorite = $0 }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringFavorite || isFav)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(width: 600, height: 400)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay(Color.black.opacity(0.3))
        )
    }
}

// MARK: - VOD Poster Card

struct VODPosterCard: View {
    let item: VODItem
    let onSelect: (VODItem) -> Void
    @State private var isHovering = false

    var body: some View {
        Button { onSelect(item) } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: isHovering ? Color.appAccent.opacity(0.2) : .black.opacity(0.2), radius: isHovering ? 15 : 8, x: 0, y: isHovering ? 10 : 4)

                    IsolatedVODPoster(streamIcon: item.streamIcon, name: item.name)

                    if let rating = item.rating, !rating.isEmpty, rating != "0", rating != "0.0" {
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.yellow)
                                    Text(rating)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                        .mask(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                )
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .padding(8)
                            }
                            Spacer()
                        }
                    }

                    if isHovering {
                        ZStack {
                            VisualEffectView(material: .selection, blendingMode: .withinWindow)
                                .opacity(0.4)
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(item.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isHovering)
    }
}

// MARK: - Isolated Poster Views

struct IsolatedSeriesPoster: View {
    let coverUrl: String?
    let name: String
    
    var body: some View {
        if let iconUrl = coverUrl, let url = URL(string: iconUrl) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 220)
                        .clipped()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    SeriesPlaceholder(name: name)
                }
            }
        } else {
            SeriesPlaceholder(name: name)
        }
    }
}

struct IsolatedVODPoster: View {
    let streamIcon: String?
    let name: String
    
    var body: some View {
        if let iconUrl = streamIcon, let url = URL(string: iconUrl) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 220)
                        .clipped()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VODPlaceholder(name: name)
                }
            }
        } else {
            VODPlaceholder(name: name)
        }
    }
}
