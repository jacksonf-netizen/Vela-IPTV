import SwiftUI

struct VODSidebarView: View {
    @ObservedObject var vodVM: VODViewModel
    @ObservedObject var seriesVM: SeriesViewModel
    @Binding var selectedCategory: VODSidebarSelection
    @ObservedObject private var persistence = PersistenceService.shared
    @State private var expandedVODProviderIds: Set<UUID> = []
    @State private var expandedSeriesProviderIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    Spacer().frame(height: 4) // Top Cushion

                    // MARK: – Library
                    SidebarSectionHeader(title: "LIBRARY")

                    SidebarNavItem(
                        icon: "clock.fill",
                        title: "Recently Watched",
                        isSelected: selectedCategory == .recents,
                        accentColor: .orange
                    ) { selectedCategory = .recents }

                    SidebarNavItem(
                        icon: "heart.fill",
                        title: "Favorites",
                        isSelected: selectedCategory == .favorites,
                        accentColor: .pink
                    ) { selectedCategory = .favorites }

                    Divider()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .opacity(0.3)

                    // MARK: – Browse
                    SidebarSectionHeader(title: "BROWSE")

                    SidebarNavItem(
                        icon: "film.fill",
                        title: "All Movies",
                        isSelected: selectedCategory == .allMovies,
                        accentColor: .purple
                    ) { selectedCategory = .allMovies }

                    SidebarNavItem(
                        icon: "tv",
                        title: "All TV Shows",
                        isSelected: selectedCategory == .allSeries,
                        accentColor: .indigo
                    ) { selectedCategory = .allSeries }

                    Divider()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .opacity(0.3)

                    // MARK: – Providers
                    SidebarSectionHeader(title: "PROVIDERS")

                    ForEach(persistence.providers) { provider in
                        providerSection(provider: provider)
                    }
                }
                .padding(.bottom, 10)
            }
            .frame(minHeight: 0, idealHeight: 100, maxHeight: .infinity)
        }
        .padding(.vertical, 0)
        .padding(.leading, 0)
    }

    @ViewBuilder
    private func providerSection(provider: Provider) -> some View {
        let isMoviesExpanded = expandedVODProviderIds.contains(provider.id)
        let isSeriesExpanded = expandedSeriesProviderIds.contains(provider.id)

        Divider()
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
            .opacity(0.2)

        // Provider name as a static header
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appAccent)
            }
            Text(provider.name.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)

        // Movie categories toggle
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if isMoviesExpanded {
                    expandedVODProviderIds.remove(provider.id)
                } else {
                    expandedVODProviderIds.insert(provider.id)
                    if vodVM.vodCategoriesByProvider[provider.id] == nil {
                        Task { await vodVM.loadVODCategories(for: provider.id, credentials: provider.credentials) }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "film.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isMoviesExpanded ? Color.purple : Color.appTextSecondary)
                    .frame(width: 18)
                Text("Movie Categories")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isMoviesExpanded ? .white : Color.appTextSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.appTextSecondary.opacity(0.5))
                    .rotationEffect(.degrees(isMoviesExpanded ? 90 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isMoviesExpanded {
            let vodCats = vodVM.vodCategoriesByProvider[provider.id] ?? []

            if vodCats.isEmpty && vodVM.isLoadingCategories {
                HStack(spacing: 12) {
                    VelaIPTVSpinner(size: 14, lineWidth: 2)
                    Text("Loading…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 6)
            }

            ForEach(vodCats) { cat in
                CategoryRow(
                    category: cat,
                    isSelected: selectedCategory == .category(cat, providerId: provider.id),
                    isHidden: false,
                    onSelect: { selectedCategory = .category(cat, providerId: provider.id) }
                )
            }
        }

        // Series categories toggle
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if isSeriesExpanded {
                    expandedSeriesProviderIds.remove(provider.id)
                } else {
                    expandedSeriesProviderIds.insert(provider.id)
                    if seriesVM.seriesCategoriesByProvider[provider.id] == nil {
                        Task { await seriesVM.loadSeriesCategories(for: provider.id, credentials: provider.credentials) }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tv")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSeriesExpanded ? Color.indigo : Color.appTextSecondary)
                    .frame(width: 18)
                Text("TV Show Categories")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSeriesExpanded ? .white : Color.appTextSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.appTextSecondary.opacity(0.5))
                    .rotationEffect(.degrees(isSeriesExpanded ? 90 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isSeriesExpanded {
            let seriesCats = seriesVM.seriesCategoriesByProvider[provider.id] ?? []

            if seriesCats.isEmpty && seriesVM.isLoadingCategories {
                HStack(spacing: 12) {
                    VelaIPTVSpinner(size: 14, lineWidth: 2)
                    Text("Loading…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 6)
            }

            ForEach(seriesCats) { cat in
                CategoryRow(
                    category: cat,
                    isSelected: selectedCategory == .seriesCategory(cat, providerId: provider.id),
                    isHidden: false,
                    onSelect: { selectedCategory = .seriesCategory(cat, providerId: provider.id) }
                )
            }
        }
    }
}

enum VODSidebarSelection: Equatable {
    case recents
    case favorites
    case allMovies
    case search
    case allSeries
    case searchSeries
    case category(StreamCategory, providerId: UUID)
    case seriesCategory(StreamCategory, providerId: UUID)

    static func == (lhs: VODSidebarSelection, rhs: VODSidebarSelection) -> Bool {
        switch (lhs, rhs) {
        case (.recents, .recents): return true
        case (.favorites, .favorites): return true
        case (.allMovies, .allMovies): return true
        case (.search, .search): return true
        case (.allSeries, .allSeries): return true
        case (.searchSeries, .searchSeries): return true
        case (.category(let a, let aid), .category(let b, let bid)):
            return a.categoryId == b.categoryId && aid == bid
        case (.seriesCategory(let a, let aid), .seriesCategory(let b, let bid)):
            return a.categoryId == b.categoryId && aid == bid
        default: return false
        }
    }
}
