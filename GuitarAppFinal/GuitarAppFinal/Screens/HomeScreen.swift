import SwiftUI
import SwiftData

/// The Moods tab. Shows the mood grid (design 1A) once there are songs, and the
/// first-launch "Add your first song" screen (1B) before that.
struct HomeScreen: View {
    @Query(sort: \Mood.sortOrder) private var moods: [Mood]
    @Query private var songs: [Song]

    /// Screens pushed on top of Home (song list, song).
    @State private var path: [HomeRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if songs.isEmpty {
                    FirstLaunchHome(moods: moods)
                } else {
                    MoodGridHome(moods: moods, songs: songs) { path.append($0) }
                }
            }
            .clearsTabBar()
            // Home draws its own glass buttons; pushed screens use the system bar's back button.
            .toolbarVisibility(.hidden, for: .navigationBar)
            .appRouteDestinations()
        }
    }
}

// MARK: - 1A · With songs

private struct MoodGridHome: View {
    var moods: [Mood]
    var songs: [Song]
    var open: (HomeRoute) -> Void

    /// The home glow uses the Campfire tint, as in the design.
    private let glowColor = Color(moodHue: 50)

    /// The mood whose "Who's listening?" sheet is showing.
    @State private var crowdSheetMood: Mood?

    @Environment(SheetRouter.self) private var router: SheetRouter?
    /// All / English / Nepali / Hindi, remembered between launches.
    @AppStorage("languageFilter") private var language: LanguageFilter = .all

    /// The songs that pass the language filter; everything on Home counts these.
    private var shownSongs: [Song] { songs.filtered(by: language) }
    private var readySongs: [Song] { shownSongs.filter(\.isReady) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Spacer()
                    // Search isn't specified in the PRD yet, so this does nothing for now.
                    GlassCircleButton(symbol: "magnifyingglass", accessibilityLabel: "Search") {}
                    GlassCircleButton(symbol: "plus", accessibilityLabel: "Add song") { router?.addSong() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Moodchords")
                        .themeFont(.largeTitle)
                        .foregroundStyle(Theme.fg)
                        .accessibilityAddTraits(.isHeader)
                    Text("What's the vibe tonight?")
                        .themeFont(.body)
                        .foregroundStyle(Theme.fg2)
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)

                surprisePill
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                LanguageChips(selection: $language, songs: songs)
                    .padding(.top, 16)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(moods) { mood in
                        Button {
                            crowdSheetMood = mood
                        } label: {
                            MoodTile(
                                mood: mood.swatch,
                                countLabel: MoodTile.countLabel(for: MoodLibrary.songs(for: mood, in: shownSongs).count)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Manage moods", systemImage: "slider.horizontal.3") { open(.moods) }
                        }
                    }
                    Button {
                        open(.moods)
                    } label: {
                        NewMoodTile()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .moodGlow(glowColor)
        .crowdSheet(mood: $crowdSheetMood, songs: shownSongs) { mood, crowd in
            open(.songList(mood, crowd))
        }
    }

    /// "Surprise me" picks from ready songs only, so it's dimmed until at least one is marked ready.
    private var surprisePill: some View {
        let count = readySongs.count
        let subtitle = switch count {
        case 0: "Mark songs ready to play first"
        case 1: "From 1 song you're ready to play"
        default: "From \(count) songs you're ready to play"
        }
        return AccentPill(title: "Surprise me", subtitle: subtitle) {
            if let song = readySongs.randomElement() {
                open(.song(song))
            }
        }
        .disabled(count == 0)
        .opacity(count == 0 ? 0.55 : 1)
    }
}

/// All · English · Nepali · Hindi, each with its song count.
struct LanguageChips: View {
    @Binding var selection: LanguageFilter
    var songs: [Song]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(LanguageFilter.allCases) { option in
                    let count = songs.filtered(by: option).count
                    Button {
                        selection = option
                    } label: {
                        Chip(title: "\(option.title) \(count)", style: option == selection ? .selected : .option)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.title), \(CrowdSheet.songCount(count))")
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - 1B · First launch

private struct FirstLaunchHome: View {
    var moods: [Mood]

    @Environment(SheetRouter.self) private var router: SheetRouter?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    GlassCircleButton(symbol: "plus", accessibilityLabel: "Add song") { router?.addSong() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                Text("Moodchords")
                    .themeFont(.largeTitle)
                    .foregroundStyle(Theme.fg)
                    .padding(.horizontal, 22)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 12) {
                    SpecLabel("\"Oe, baja ta!\"", color: Theme.chord)
                    Text("Add your first song")
                        .font(Theme.font(size: 38, weight: .heavy))
                        .foregroundStyle(Theme.fg)
                        .accessibilityAddTraits(.isHeader)
                    Text("Paste a chord sheet or import a file. Next time someone asks you to play, it's already sorted by mood.")
                        .themeFont(.body)
                        .foregroundStyle(Theme.fg2)
                        .lineSpacing(3)
                }
                .frame(maxWidth: 300, alignment: .leading)
                .padding(.horizontal, 24)
                // The design's 96 pt leaves the last chips under the tab bar with SF Pro's taller lines.
                .padding(.top, 56)

                VStack(spacing: 10) {
                    AccentCapsuleButton(title: "Paste song", symbol: "doc.on.clipboard") { router?.paste() }
                    GlassCapsuleButton(title: "Import file", symbol: "arrow.up.doc", note: ".txt · .cho") {
                        router?.importFiles()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 10) {
                    SpecLabel("Your songs will sort into")
                    FlowLayout(rowSpacing: 6, itemSpacing: 6) {
                        ForEach(moods) { mood in
                            Chip(title: mood.name, style: .mood(mood.swatch))
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 34)
                .padding(.bottom, 24)
            }
        }
        .background {
            // The big faded "BAJA TA" running down the right edge, behind everything.
            // Positioned from the very top of the screen (120 pt), bleeding 26 pt off the right.
            Theme.bg
                .overlay(alignment: .topTrailing) {
                    QuarterTurnLayout {
                        Text("BAJA TA")
                            .font(Theme.displayFont(size: 168))
                            .foregroundStyle(Theme.chip)
                            .fixedSize()
                            .rotationEffect(.degrees(90))
                    }
                    .offset(x: 26, y: 120)
                }
                .clipped()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }
}

#Preview("1A · With songs") {
    HomeScreen()
        .modelContainer(PreviewData.container())
}

#Preview("1A · Dark") {
    HomeScreen()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
}

#Preview("1B · First launch") {
    HomeScreen()
        .modelContainer(PreviewData.container(withSongs: false))
}

#Preview("1B · Dark") {
    HomeScreen()
        .modelContainer(PreviewData.container(withSongs: false))
        .preferredColorScheme(.dark)
}
