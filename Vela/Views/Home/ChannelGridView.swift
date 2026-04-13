import SwiftUI

struct ChannelGridView: View {
    let channels: [Channel]
    @Binding var searchQuery: String
    let isLoading: Bool
    let sectionTitle: String
    let onSelect: (Channel) -> Void
    @ObservedObject private var persistence = PersistenceService.shared
    
    enum ListMode: String, CaseIterable, Identifiable {
        case cards = "Cards"
        case tvGuide = "TV Guide"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .cards: return "square.grid.2x2"
            case .tvGuide: return "list.bullet.rectangle.portrait"
            }
        }
    }
    
    @AppStorage("vela.ui.channelViewMode") private var listMode: ListMode = .cards
    @Namespace private var viewModeNamespace

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Apple-style Modern Header
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sectionTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("\(channels.count) channels")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Layout Toggle & Search Bar
                HStack(spacing: 12) {
                    // View Switcher Pill
                    HStack(spacing: 0) {
                        ForEach(ListMode.allCases) { m in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    listMode = m
                                }
                            } label: {
                                Image(systemName: m.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(listMode == m ? .white : Color.appTextSecondary)
                                    .frame(width: 40, height: 32)
                                    .background(
                                        ZStack {
                                            if listMode == m {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.white.opacity(0.12))
                                                    .matchedGeometryEffect(id: "viewModePill", in: viewModeNamespace)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                    // Search Bar Container
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                        
                        TextField("Search your library…", text: $searchQuery)
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
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 16)

            if isLoading {
                Spacer()
                VStack(spacing: 16) {
                    VelaIPTVSpinner(size: 44, lineWidth: 4)
                    Text("Fetching Streams…")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
            } else if channels.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "tv.slash.fill",
                    title: "No channels found",
                    subtitle: searchQuery.isEmpty ? "This collection is currently empty." : "Try adjusting your search filters."
                )
                Spacer()
            } else {
                if listMode == .cards {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(channels) { channel in
                                ChannelCardView(
                                    channel: channel,
                                    isFavorite: persistence.isFavorite(channel),
                                    onSelect: onSelect,
                                    onFavoriteToggle: { persistence.toggleFavorite(channel) }
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                    .frame(minHeight: 0, idealHeight: 100, maxHeight: .infinity)
                } else {
                    EPGGridView(
                        channels: channels,
                        searchQuery: $searchQuery,
                        isLoading: isLoading,
                        sectionTitle: sectionTitle,
                        onSelect: onSelect
                    )
                }
            }
        }
        .background(Color.clear)
    }
}

struct ChannelCardView: View {
    let channel: Channel
    let isFavorite: Bool
    let onSelect: (Channel) -> Void
    let onFavoriteToggle: () -> Void

    @State private var isHovering = false
    @State private var isHoveringHeart = false

    var body: some View {
        Button { onSelect(channel) } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Large Glassmorphic Logo Container
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: isHovering ? Color.appAccent.opacity(0.2) : .black.opacity(0.2), radius: isHovering ? 15 : 8, x: 0, y: isHovering ? 10 : 4)

                    if let iconUrl = channel.streamIcon, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(24)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                ChannelPlaceholder(name: channel.name)
                            }
                        }
                    } else {
                        ChannelPlaceholder(name: channel.name)
                    }

                    // Premium Badges
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.appLiveRed)
                                    .frame(width: 6, height: 6)
                                    .opacity(isHovering ? 1.0 : 0.6)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: isHovering)
                                
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                    .mask(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            )
                            .background(Color.appLiveRed.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(10)
                        }
                        Spacer()
                    }

                    // Play Overlay on Hover
                    if isHovering {
                        ZStack {
                            VisualEffectView(material: .selection, blendingMode: .withinWindow)
                                .opacity(0.4)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .transition(.opacity.combined(with: .scale))
                    }

                    // Interactive Favorite Toggle (Placed ABOVE the hover overlay)
                    VStack {
                        Spacer()
                        HStack {
                            Button {
                                onFavoriteToggle()
                            } label: {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(
                                        isFavorite 
                                        ? Color.appFavoriteRed.opacity(isHoveringHeart ? 1.0 : 0.9) 
                                        : Color.white.opacity(isHoveringHeart ? 0.3 : 0.15)
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: isFavorite ? Color.appFavoriteRed.opacity(0.4) : .black.opacity(0.2), radius: 6, x: 0, y: 3)
                                    .scaleEffect(isHoveringHeart ? 1.15 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHoveringHeart = $0 }
                            .padding(10)
                            Spacer()
                        }
                    }
                }
                .frame(height: 140)

                // Meta Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(channel.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    ProviderBadge(providerId: channel.providerId)
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isHovering)
        .contextMenu {
            Button { onFavoriteToggle() } label: {
                Label(isFavorite ? "Dislike" : "Love It", systemImage: isFavorite ? "heart.slash.fill" : "heart.fill")
            }
            Divider()
            Button { onSelect(channel) } label: {
                Label("Play Fullscreen", systemImage: "play.fill")
            }
        }
    }
}

struct ChannelPlaceholder: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 64))
                .foregroundColor(Color.appAccent.opacity(0.6))
                .shadow(color: Color.appAccent.opacity(0.2), radius: 20)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
    }
}
