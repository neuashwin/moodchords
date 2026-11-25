import SwiftUI
import SwiftData

/// Screens the Moods and Favourites tabs can push.
enum HomeRoute: Hashable {
    case songList(Mood, CrowdFilter)
    case song(Song)
    /// Manage moods (design 10A).
    case moods
}

extension View {
    /// Registers the screens every tab's navigation stack can push.
    func appRouteDestinations() -> some View {
        navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .songList(let mood, let crowd):
                SongListScreen(mood: mood, crowd: crowd)
            case .song(let song):
                SongScreen(song: song)
            case .moods:
                MoodsScreen()
            }
        }
    }
}

/// One song in a list: ready mark, title, artist, mono meta line, first line and favourite star.
/// Tapping opens the song; long-pressing shows quick actions (design 3C).
struct SongRow: View {
    var song: Song

    var body: some View {
        let summary = song.summary
        NavigationLink(value: HomeRoute.song(song)) {
            HStack(alignment: .top, spacing: 12) {
                ReadyMark(isReady: song.isReady)

                VStack(alignment: .leading, spacing: 0) {
                    Text(song.title)
                        .font(Theme.font(size: 18, weight: .bold))
                        .foregroundStyle(Theme.fg)
                        .multilineTextAlignment(.leading)
                    if let artist = song.artist {
                        Text(artist)
                            .font(Theme.font(.callout))
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.fg2)
                    }
                    Text(summary.metaLine)
                        .font(Theme.font(size: 11.5, mono: true))
                        .tracking(0.35)
                        .foregroundStyle(Theme.fg)
                        .padding(.top, 7)
                    Text(summary.cueLine)
                        .font(Theme.font(size: 13.5))
                        .italic()
                        .foregroundStyle(Theme.fg2)
                        .lineLimit(1)
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The words get the room; the ready mark and star stay their own size.
                .layoutPriority(1)

                Image(systemName: song.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 20))
                    .foregroundStyle(song.isFavorite ? Theme.chord : Theme.fg3)
                    .frame(width: 24, height: 26)
                    .accessibilityLabel(song.isFavorite ? "Favourite" : "")
                    .accessibilityHidden(!song.isFavorite)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .contextMenu {
            SongQuickActions(song: song)
        }
    }
}

/// The long-press menu for a song.
struct SongQuickActions: View {
    var song: Song

    @Environment(SheetRouter.self) private var router: SheetRouter?

    var body: some View {
        Button(song.isFavorite ? "Unfavourite" : "Favourite",
               systemImage: song.isFavorite ? "star.slash" : "star") {
            song.isFavorite.toggle()
        }
        Button(song.isReady ? "Mark not ready" : "Mark ready to play",
               systemImage: song.isReady ? "checkmark.circle.badge.xmark" : "checkmark.circle") {
            song.isReady.toggle()
        }
        // Setlists arrive in M5.
        Button("Add to setlist…", systemImage: "text.badge.plus") {}
            .disabled(true)
        Divider()
        Button("Edit song", systemImage: "pencil") {
            router?.edit(song)
        }
    }
}

/// A rounded card holding rows separated by hairlines (one per list section).
struct SongCard: View {
    var songs: [Song]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                if index > 0 {
                    Rectangle().fill(Theme.line).frame(height: 0.5)
                }
                SongRow(song: song)
            }
        }
        .background(Theme.card, in: .rect(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.line, lineWidth: 0.5) }
        .clipShape(.rect(cornerRadius: 26))
        .shadow(color: .black.opacity(0.06), radius: 15, y: 10)
    }
}
