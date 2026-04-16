import SwiftUI

struct RecentView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    let onSelect: (Channel) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Apple-style Modern Header
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recents")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("\(persistence.recents.count) channels")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                
                if !persistence.recents.isEmpty {
                    Button(action: { persistence.clearRecents() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .bold))
                            Text("Clear History")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
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

            if persistence.recents.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Nothing watched yet",
                    subtitle: "Channels you watch will appear here for lightning fast access."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(persistence.recents) { entry in
                            RecentChannelCard(
                                entry: entry,
                                isFavorite: persistence.isFavorite(entry.channel),
                                onSelect: onSelect,
                                onFavoriteToggle: { persistence.toggleFavorite(entry.channel) },
                                onRemove: { persistence.removeRecent(entry) }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
                .scrollClipDisabled()
            }
        }
        .background(Color.clear)
    }
}

struct RecentChannelCard: View {
    let entry: RecentEntry
    let isFavorite: Bool
    let onSelect: (Channel) -> Void
    let onFavoriteToggle: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false
    @State private var isHoveringHeart = false

    var timeAgoString: String {
        let diff = Date().timeIntervalSince(entry.watchedAt)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }

    var body: some View {
        Button { onSelect(entry.channel) } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Large Glassmorphic Logo Container
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: isHovering ? Color.appAccent.opacity(0.2) : .black.opacity(0.2), radius: isHovering ? 15 : 8, x: 0, y: isHovering ? 10 : 4)

                    if let iconUrl = entry.channel.streamIcon, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(24)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                ChannelPlaceholder(name: entry.channel.name)
                            }
                        }
                    } else {
                        ChannelPlaceholder(name: entry.channel.name)
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

                    // Time Badge & Favorite Toggle (Placed ABOVE the hover overlay)
                    VStack {
                        Spacer()
                        HStack {
                            // Favorite Toggle (Bottom Left)
                            Button {
                                onFavoriteToggle()
                            } label: {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(
                                        isFavorite 
                                        ? Color.appFavoriteRed.opacity(isHoveringHeart ? 1.0 : 0.9) 
                                        : Color.white.opacity(isHoveringHeart ? 0.3 : 0.15)
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: isFavorite ? Color.appFavoriteRed.opacity(0.4) : .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    .scaleEffect(isHoveringHeart ? 1.15 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHoveringHeart = $0 }
                            
                            Spacer()

                            // Time Badge (Bottom Right)
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
                        }
                        .padding(10)
                    }
                }
                .frame(height: 140)

                // Meta Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.channel.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    ProviderBadge(providerId: entry.channel.providerId)
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
            Button { onSelect(entry.channel) } label: {
                Label("Play Fullscreen", systemImage: "play.fill")
            }
            Divider()
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove from Recents", systemImage: "xmark.circle")
            }
        }
    }
}
