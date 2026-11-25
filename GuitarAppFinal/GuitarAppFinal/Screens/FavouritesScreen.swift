import SwiftUI
import SwiftData

/// The Favourites tab (design 9A): every starred song, with its mood colour.
struct FavouritesScreen: View {
    @Query(filter: #Predicate<Song> { $0.isFavorite }, sort: \Song.title) private var favourites: [Song]
    @Query(sort: \Mood.sortOrder) private var moods: [Mood]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Favourites")
                        .themeFont(.largeTitle)
                        .foregroundStyle(Theme.fg)
                        .accessibilityAddTraits(.isHeader)
                    SpecLabel(CrowdSheet.songCount(favourites.count))
                        .padding(.top, 10)

                    if favourites.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(favourites.enumerated()), id: \.element.id) { index, song in
                                if index > 0 { Rectangle().fill(Theme.line).frame(height: 0.5) }
                                FavouriteRow(song: song, mood: moods.first { song.hasMood(named: $0.name) })
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 26))
                        .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.line, lineWidth: 0.5) }
                        .clipShape(.rect(cornerRadius: 26))
                        .shadow(color: .black.opacity(0.06), radius: 15, y: 10)
                        .padding(.horizontal, -6)
                        .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 54)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .clearsTabBar()
            .toolbarVisibility(.hidden, for: .navigationBar)
            .appRouteDestinations()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Theme.chord)
                .frame(width: 84, height: 84)
                .background(Theme.chip, in: .circle)
                .accessibilityHidden(true)
            Text("No favourites yet")
                .font(Theme.font(size: 24, weight: .heavy))
                .foregroundStyle(Theme.fg)
            Text("Long-press any song and tap Favourite, or use the star on its page.")
                .font(Theme.font(size: 16))
                .foregroundStyle(Theme.fg2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
        .padding(.horizontal, 14)
    }
}

/// A favourite: the mood's colour square, title, artist, spec line and a filled star.
private struct FavouriteRow: View {
    var song: Song
    var mood: Mood?

    var body: some View {
        NavigationLink(value: HomeRoute.song(song)) {
            HStack(spacing: 12) {
                Image(systemName: mood?.symbol ?? "music.note")
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.moodInk)
                    .frame(width: 44, height: 44)
                    .background(mood?.swatch.color ?? Theme.chip, in: .rect(cornerRadius: 14))
                    .environment(\.colorScheme, .light)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(song.title)
                        .font(Theme.font(size: 17, weight: .bold))
                        .foregroundStyle(Theme.fg)
                        .multilineTextAlignment(.leading)
                    if let artist = song.artist {
                        Text(artist)
                            .font(Theme.font(size: 14))
                            .foregroundStyle(Theme.fg2)
                    }
                    Text(song.summary.metaLine)
                        .font(Theme.font(size: 11, mono: true))
                        .foregroundStyle(Theme.fg)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.chord)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .contextMenu { SongQuickActions(song: song) }
    }
}

#Preview(traits: .sampleLibrary) {
    FavouritesScreen()
}
