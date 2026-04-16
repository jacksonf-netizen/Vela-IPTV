import SwiftUI

struct VODGridView: View {
    let items: [VODItem]
    @Binding var searchQuery: String
    @Binding var filterProviderId: UUID?
    let isLoading: Bool
    let sectionTitle: String
    let onSelect: (VODItem) -> Void
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

                    Text("\(items.count) movies")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)

                        TextField("Search movies…", text: $searchQuery)
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
                    Text("Fetching Movies…")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
            } else if !isLoading && items.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "film.fill",
                    title: "No movies found",
                    subtitle: searchQuery.isEmpty ? "This collection is currently empty." : "Try adjusting your search filters."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(items) { item in
                            VODCardView(item: item, onSelect: onSelect)
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

struct VODCardView: View {
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

                    if let iconUrl = item.streamIcon, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 220)
                                    .clipped()
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                VODPlaceholder(name: item.name)
                            }
                        }
                    } else {
                        VODPlaceholder(name: item.name)
                    }

                    // Rating badge
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

struct VODPlaceholder: View {
    let name: String
    var body: some View {
        ZStack {
            Color.appSurface

            Text(name.prefix(1).uppercased())
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(Color.appAccent.opacity(0.4))

            Image(systemName: "film")
                .font(.system(size: 20))
                .foregroundColor(Color.appAccent.opacity(0.2))
                .offset(y: 30)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
