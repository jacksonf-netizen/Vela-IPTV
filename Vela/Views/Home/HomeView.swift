import SwiftUI
import Combine
import Foundation

enum AppTab: String, CaseIterable {
    case liveTV = "Live TV"
    case movies = "Movies & TV"

    var icon: String {
        switch self {
        case .liveTV: return "tv.fill"
        case .movies: return "popcorn.fill"
        }
    }
}

struct HomeView: View {
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject private var persistence = PersistenceService.shared
    @StateObject private var channelVM = ChannelViewModel()
    @StateObject private var vodVM = VODViewModel()
    @StateObject private var seriesVM = SeriesViewModel()
    @State private var activeTab: AppTab
    @State private var selectedSection: SidebarSection
    @State private var selectedChannel: Channel? = nil
    @State private var showPlayer = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var vodOverrideURL: URL? = nil
    @State private var isVODPlayback = false

    init(authVM: AuthViewModel) {
        self.authVM = authVM

        let settings = PersistenceService.shared.settings
        _activeTab = State(initialValue: settings.showVOD ? (settings.defaultTab == .movies ? .movies : .liveTV) : .liveTV)

        switch settings.startupScreen {
        case .recents:
            _selectedSection = State(initialValue: .recents)
        case .favorites:
            _selectedSection = State(initialValue: .favorites)
        }
    }

    var activeProvider: Provider? { persistence.activeProvider }

    private func playSeriesEpisode(_ episode: SeriesEpisode, from series: SeriesItem) {
        guard let provider = persistence.providers.first(where: { $0.id == series.providerId }) ?? activeProvider else { return }
        guard let url = provider.credentials.seriesEpisodeURL(episodeId: episode.id, containerExtension: episode.containerExtension) else { return }
        let epTitle = episode.title.map { " - \($0)" } ?? ""
        let title = "\(series.name) S\(episode.season)E\(episode.episodeNum)\(epTitle)"
        let syntheticChannel = Channel(
            num: nil,
            name: title,
            streamType: "series",
            streamId: episode.id,
            streamIcon: series.cover,
            epgChannelId: nil,
            added: nil,
            categoryId: series.categoryId,
            customSid: nil,
            tvArchive: nil,
            directSource: nil,
            tvArchiveDuration: nil,
            providerId: series.providerId
        )
        selectedChannel = syntheticChannel
        vodOverrideURL = url
        isVODPlayback = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPlayer = true }
    }

    private func playVODItem(_ item: VODItem) {
        guard let provider = persistence.providers.first(where: { $0.id == item.providerId }) ?? activeProvider else { return }
        let url = provider.credentials.vodStreamURL(for: item)
        let syntheticChannel = Channel(
            num: item.num, name: item.name, streamType: "movie", streamId: item.streamId,
            streamIcon: item.streamIcon, epgChannelId: nil, added: item.added,
            categoryId: item.categoryId, customSid: nil, tvArchive: nil,
            directSource: nil, tvArchiveDuration: nil, providerId: item.providerId
        )
        selectedChannel = syntheticChannel
        vodOverrideURL = url
        isVODPlayback = true
        persistence.addVODRecent(item)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPlayer = true }
    }

    private var activeChannels: [Channel] {
        switch selectedSection {
        case .recents: return persistence.recents.map { $0.channel }
        case .favorites: return persistence.favorites
        case .search: return []
        case .category(_, _): return channelVM.filteredChannels
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if !showPlayer {
                ZStack {
                    liveTVContent
                        .opacity(activeTab == .liveTV ? 1 : 0)
                        .allowsHitTesting(activeTab == .liveTV)

                    MoviesView(
                        authVM: authVM,
                        vodVM: vodVM,
                        seriesVM: seriesVM,
                        activeTab: $activeTab,
                        columnVisibility: $columnVisibility,
                        onPlayItem: { item in playVODItem(item) },
                        onPlayEpisode: { episode, series in playSeriesEpisode(episode, from: series) }
                    )
                    .opacity(activeTab == .movies ? 1 : 0)
                    .allowsHitTesting(activeTab == .movies)
                }
                .animation(.easeInOut(duration: 0.2), value: activeTab)
            }

            // MARK: – Full-Screen Player Overlay
            if showPlayer, let channel = selectedChannel {
                let provider = persistence.providers.first { $0.id == channel.providerId } ?? activeProvider

                if let _ = provider {
                    PlayerView(
                        initialChannel: channel,
                        channels: isVODPlayback ? [] : activeChannels,
                        authVM: authVM,
                        categories: channelVM.categories,
                        isPresented: $showPlayer,
                        overrideStreamURL: vodOverrideURL,
                        isVOD: isVODPlayback
                    )
                    .background(Color.black)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(100)
                    .onChange(of: showPlayer) { _, isShowing in
                        if !isShowing {
                            vodOverrideURL = nil
                            isVODPlayback = false
                        }
                    }
                }
            }
        }
        .task(id: activeProvider?.id) {
            if let provider = activeProvider {
                channelVM.setup(credentials: provider.credentials)
                await channelVM.loadCategories()
                vodVM.setup(credentials: provider.credentials)
            }
        }
        .onChange(of: selectedSection) { _, newSection in
            if case .category(let cat, let providerId) = newSection, let pId = providerId {
                if let provider = persistence.providers.first(where: { $0.id == pId }) {
                    if persistence.activeProviderId != pId {
                        persistence.setActiveProvider(provider)
                    }
                    Task {
                        channelVM.setup(credentials: provider.credentials)
                        await channelVM.loadCategories()
                        await channelVM.selectCategory(cat, providerId: pId)
                    }
                }
            }
        }
        .sheet(isPresented: $authVM.isShowingAddProvider) {
            AddProviderView(authVM: authVM, isSheet: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .velaWillTerminate)) { _ in
            authVM.isShowingAddProvider = false
        }
    }

    // MARK: – Live TV Content

    private var liveTVContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                categories: channelVM.fullCategories,
                selectedSection: $selectedSection,
                isLoading: channelVM.isLoadingCategories,
                authVM: authVM,
                channelVM: channelVM
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)

        } detail: {
            ZStack {
                
                switch selectedSection {
                case .recents:
                    RecentView(onSelect: { channel in
                        selectedChannel = channel
                        vodOverrideURL = nil
                        isVODPlayback = false
                        if let pId = channel.providerId, persistence.activeProviderId != pId {
                            if let provider = persistence.providers.first(where: { $0.id == pId }) {
                                persistence.setActiveProvider(provider)
                            }
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPlayer = true }
                    })
                case .favorites:
                    FavoritesView(onSelect: { channel in
                        selectedChannel = channel
                        vodOverrideURL = nil
                        isVODPlayback = false
                        if let pId = channel.providerId, persistence.activeProviderId != pId {
                            if let provider = persistence.providers.first(where: { $0.id == pId }) {
                                persistence.setActiveProvider(provider)
                            }
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPlayer = true }
                    })
                case .search:
                    GlobalSearchView(onSelect: { channel in
                        selectedChannel = channel
                        vodOverrideURL = nil
                        isVODPlayback = false
                        if let pId = channel.providerId, persistence.activeProviderId != pId {
                            if let provider = persistence.providers.first(where: { $0.id == pId }) {
                                persistence.setActiveProvider(provider)
                            }
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPlayer = true }
                    })
                case .category(let cat, _):
                    ChannelGridView(
                        channels: channelVM.filteredChannels,
                        searchQuery: $channelVM.searchQuery,
                        isLoading: channelVM.isLoadingChannels,
                        sectionTitle: cat?.categoryName ?? "All Channels",
                        onSelect: { channel in
                            selectedChannel = channel
                            vodOverrideURL = nil
                            isVODPlayback = false
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPlayer = true }
                        }
                    )
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            if persistence.settings.showVOD {
                ToolbarItem(placement: .principal) {
                    AppTabBar(activeTab: $activeTab)
                }
            }
        }
    }
}

// MARK: – App Tab Bar

struct AppTabBar: View {
    @Binding var activeTab: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        activeTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(activeTab == tab ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(activeTab == tab ? Color.appAccent : Color.clear)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        .colorScheme(.dark)
    }
}

// MARK: – Sidebar Section

enum SidebarSection: Equatable {
    case recents
    case favorites
    case search
    case category(StreamCategory?, providerId: UUID?)

    static func == (lhs: SidebarSection, rhs: SidebarSection) -> Bool {
        switch (lhs, rhs) {
        case (.recents, .recents): return true
        case (.favorites, .favorites): return true
        case (.search, .search): return true
        case (.category(let a, let aid), .category(let b, let bid)):
            return a?.categoryId == b?.categoryId && aid == bid
        default: return false
        }
    }
}

// MARK: – Global Search

@MainActor
class GlobalSearchViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var resultsByProvider: [UUID: [Channel]] = [:]
    @Published var isSearching: Bool = false
    @Published var loadingProviders: Set<UUID> = []

    private let persistence = PersistenceService.shared
    private let service = XtreamCodesService.shared
    private var cancellables = Set<AnyCancellable>()

    private var providerChannelCache: [UUID: [Channel]] = [:]

    init() {
        $searchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            resultsByProvider = [:]
            return
        }

        var finalResults: [UUID: [Channel]] = [:]
        let q = trimmedQuery.lowercased()

        for provider in persistence.providers {
            if let cachedChannels = providerChannelCache[provider.id] {
                let matches = cachedChannels.filter { channel in
                    !persistence.isCategoryHidden(channel.categoryId ?? "", providerId: provider.id) &&
                    channel.name.lowercased().contains(q)
                }
                if !matches.isEmpty {
                    finalResults[provider.id] = matches
                }
            } else {
                Task {
                    await fetchAndSearch(provider: provider, query: q)
                }
            }
        }

        self.resultsByProvider = finalResults
    }

    private func fetchAndSearch(provider: Provider, query: String) async {
        guard !loadingProviders.contains(provider.id) else { return }

        loadingProviders.insert(provider.id)
        defer { loadingProviders.remove(provider.id) }

        do {
            let channels = try await service.getLiveStreams(credentials: provider.credentials, providerId: provider.id)
            providerChannelCache[provider.id] = channels

            let q = searchQuery.lowercased()
            if !q.isEmpty {
                let matches = channels.filter { channel in
                    !persistence.isCategoryHidden(channel.categoryId ?? "", providerId: provider.id) &&
                    channel.name.lowercased().contains(q)
                }
                if !matches.isEmpty {
                    await MainActor.run {
                        resultsByProvider[provider.id] = matches
                    }
                }
            }
        } catch {
            #if DEBUG
            print("Failed to fetch search channels for \(provider.name): \(error)")
            #endif
        }
    }
}

struct GlobalSearchView: View {
    @StateObject private var vm = GlobalSearchViewModel()
    @ObservedObject private var persistence = PersistenceService.shared
    @State private var filterProviderId: UUID? = nil
    let onSelect: (Channel) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global Search")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Search channels across all providers")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    Spacer()
                }

                searchBar
            }
            .padding(.horizontal, 32)
            .padding(.top, 2)
            .padding(.bottom, 6)

            if vm.searchQuery.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: "Search Everything",
                    subtitle: "Type a channel name to search across all your accounts."
                )
            } else if vm.resultsByProvider.isEmpty {
                if !vm.loadingProviders.isEmpty {
                    loadingState
                } else {
                    emptyState(
                        icon: "questionmark.circle",
                        title: "No Results Found",
                        subtitle: "We couldn't find any channels matching \"\(vm.searchQuery)\"."
                    )
                }
            } else {
                resultsList
            }
        }
        .background(Color.clear)
    }

    private var searchBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)

                TextField("Search for channels...", text: $vm.searchQuery)
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
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(filterProviderId == nil ? Color.appAccent : .white)

                    Text(filterProviderId == nil ? "All Providers" : (persistence.providers.first(where: { $0.id == filterProviderId })?.name ?? "Filtering"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .black))
                        .opacity(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
    }

    private var resultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                let filteredProviders = persistence.providers.filter { p in
                    filterProviderId == nil || p.id == filterProviderId
                }

                ForEach(filteredProviders) { provider in
                    if let channels = vm.resultsByProvider[provider.id] {
                        VStack(alignment: .leading, spacing: 16) {
                            if filterProviderId == nil {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.appAccent)

                                    Text(provider.name.uppercased())
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(Color.appTextSecondary)
                                        .tracking(1.2)

                                    Spacer()

                                    Text("\(channels.count) matches")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color.appAccent.opacity(0.8))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.appAccent.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 4)
                            }

                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(channels) { channel in
                                    SearchChannelCard(channel: channel, showProviderBadge: filterProviderId == nil, onSelect: onSelect)
                                }
                            }
                            .padding(.top, 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .scrollClipDisabled()
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            VelaIPTVSpinner(size: 44, lineWidth: 4)
            Text("Searching all providers...")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color.appTextSecondary)
                .padding(.top, 12)
            Spacer()
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color.white.opacity(0.05))
                .padding(.bottom, 12)

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 2)
            Spacer()
        }
    }
}

struct SearchChannelCard: View {
    let channel: Channel
    let showProviderBadge: Bool
    let onSelect: (Channel) -> Void
    @State private var isHovering = false

    var body: some View {
        Button { onSelect(channel) } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: isHovering ? Color.appAccent.opacity(0.15) : .black.opacity(0.1), radius: isHovering ? 10 : 5, x: 0, y: isHovering ? 5 : 2)

                    if let iconUrl = channel.streamIcon, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fit)
                                    .padding(16)
                            } else {
                                ChannelPlaceholder(name: channel.name)
                            }
                        }
                    } else {
                        ChannelPlaceholder(name: channel.name)
                    }

                    if isHovering {
                        VisualEffectView(material: .selection, blendingMode: .withinWindow)
                            .opacity(0.3)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if showProviderBadge {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ProviderBadge(providerId: channel.providerId)
                                    .scaleEffect(0.8)
                                    .padding(4)
                            }
                        }
                    }
                }
                .frame(height: 120)

                Text(channel.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovering)
    }
}

enum SearchSortMode: String, CaseIterable, Identifiable {
    case provider = "By Provider"
    case alphabetical = "A-Z"
    var id: String { rawValue }
}
