import SwiftUI

struct SidebarView: View {
    let categories: [StreamCategory]
    @Binding var selectedSection: SidebarSection
    let isLoading: Bool
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var channelVM: ChannelViewModel
    @ObservedObject private var persistence = PersistenceService.shared
    @State private var isShowingSettings = false
    @State private var isHoveringSettings = false
    @State private var isHoveringAdd = false
    @State private var expandedProviderIds: Set<UUID> = []
    @ObservedObject private var updater = UpdaterViewModel.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {

                    // MARK: – Library
                    SidebarSectionHeader(title: "LIBRARY")

                    SidebarNavItem(
                        icon: "clock.fill",
                        title: "Recently Watched",
                        isSelected: selectedSection == .recents,
                        accentColor: .orange
                    ) { selectedSection = .recents }

                    SidebarNavItem(
                        icon: "heart.fill",
                        title: "Favorites",
                        isSelected: selectedSection == .favorites,
                        accentColor: .pink
                    ) { selectedSection = .favorites }

                    SidebarNavItem(
                        icon: "magnifyingglass",
                        title: "Global Search",
                        isSelected: selectedSection == .search,
                        accentColor: .blue
                    ) { selectedSection = .search }

                    // MARK: – Accounts
                    ForEach(persistence.providers) { provider in
                        let isExpanded = expandedProviderIds.contains(provider.id)

                        Divider()
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .opacity(0.3)

                        // MARK: – Provider Section
                        ProviderHeader(
                            name: provider.name,
                            isExpanded: isExpanded,
                            onToggle: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if isExpanded {
                                        expandedProviderIds.remove(provider.id)
                                    } else {
                                        expandedProviderIds.insert(provider.id)
                                        if channelVM.categoriesByProvider[provider.id] == nil {
                                            Task {
                                                await channelVM.loadCategories(for: provider.id, credentials: provider.credentials)
                                            }
                                        }
                                    }
                                }
                            }
                        )

                        if isExpanded {
                            let providerCats = channelVM.categoriesByProvider[provider.id] ?? []
                            let visibleCategories = providerCats.filter { !persistence.isCategoryHidden($0.categoryId, providerId: provider.id) }

                            ForEach(visibleCategories) { cat in
                                CategoryRow(
                                    category: cat,
                                    isSelected: selectedSection == .category(cat, providerId: provider.id),
                                    isHidden: false,
                                    onSelect: { selectedSection = .category(cat, providerId: provider.id) }
                                )
                            }

                            if providerCats.isEmpty && isLoading {
                                HStack(spacing: 12) {
                                    VelaIPTVSpinner(size: 14, lineWidth: 2)
                                    Text("Loading Categories…")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    if isLoading && expandedProviderIds.isEmpty {
                        HStack(spacing: 10) {
                            VelaIPTVSpinner(size: 16, lineWidth: 2)
                            Text("Syncing…")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                    }
                }
                .padding(.bottom, 10)
            }
            .frame(minHeight: 0, idealHeight: 100, maxHeight: .infinity)

            // MARK: – Sticky Footer
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.15)
                    .padding(.horizontal, 16)

                let canAddProvider = persistence.providers.count < 5
                HStack(spacing: 8) {
                    Button { authVM.isShowingAddProvider = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(canAddProvider ? Color.appAccent : Color.appTextSecondary.opacity(0.4))
                                .frame(width: 20)

                            Text(canAddProvider ? "Add Account" : "Account Limit Reached (Max 5)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(canAddProvider ? Color.appTextPrimary : Color.appTextSecondary.opacity(0.4))

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isHoveringAdd && canAddProvider ? Color.white.opacity(0.08) : Color.clear)
                        )
                        .padding(.leading, 12)
                        .padding(.bottom, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringAdd = $0 }
                    .disabled(!canAddProvider)
                    .opacity(canAddProvider ? 1.0 : 0.6)

                    Button { isShowingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 15))
                            .foregroundColor(isHoveringSettings ? .white : Color.appTextSecondary)
                            .frame(width: 38, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isHoveringSettings ? Color.white.opacity(0.08) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringSettings = $0 }
                    .padding(.trailing, 12)
                    .padding(.bottom, 6)
                }
                .padding(.bottom, 12)
            }
            .layoutPriority(1)
        }
        .padding(.vertical, 0)
        .padding(.leading, 0)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(authVM: authVM, channelVM: channelVM)
        }
        .onReceive(NotificationCenter.default.publisher(for: .velaWillTerminate)) { _ in
            isShowingSettings = false
        }
    }
}

// MARK: – Category Row
struct CategoryRow: View {
    let category: StreamCategory
    let isSelected: Bool
    let isHidden: Bool
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.appTextSecondary)
                    .frame(width: 20)

                Text(category.categoryName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : Color.appTextSecondary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.appAccent : (isHovering ? Color.white.opacity(0.08) : Color.clear))
                    .shadow(color: isSelected ? Color.appAccent.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering || isSelected)
    }
}


// MARK: – Provider Header
struct ProviderHeader: View {
    let name: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isExpanded ? Color.appAccent.opacity(0.15) : Color.white.opacity(0.06))
                        .frame(width: 24, height: 24)

                    Image(systemName: isExpanded ? "tray.full.fill" : "tray.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isExpanded ? Color.appAccent : Color.appTextSecondary)
                }

                Text(name.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isHovering || isExpanded ? .white : Color.appTextSecondary.opacity(0.8))
                    .tracking(0.5)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(isHovering || isExpanded ? Color.appAccent : Color.appTextSecondary.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.06) : Color.clear)
            )
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}


// MARK: – Shared Components
struct SidebarSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(Color.appTextSecondary.opacity(0.6))
            .tracking(0.5)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

struct SidebarNavItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : accentColor)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : Color.appTextPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accentColor)
                            .shadow(color: accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    } else if isHovering {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    }
                }
            )
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering || isSelected)
    }
}
struct AccessoryNavItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSelected ? .white : Color.appTextSecondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : Color.appTextSecondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(accentColor.opacity(0.8))
                    } else if isHovering {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering || isSelected)
    }
}
