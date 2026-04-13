import SwiftUI

struct FavoritesView: View {
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
                    Text("Favorites")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("\(persistence.favorites.count) saved channels")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 16)

            if persistence.favorites.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "heart.slash.fill",
                    title: "No favorites yet",
                    subtitle: "Press Love It in the player or context menu to keep your favorite streams here."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(persistence.favorites) { channel in
                            ChannelCardView(
                                channel: channel,
                                isFavorite: true, // It's in favorites, so always true
                                onSelect: onSelect,
                                onFavoriteToggle: { persistence.toggleFavorite(channel) }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color.clear)
    }
}
