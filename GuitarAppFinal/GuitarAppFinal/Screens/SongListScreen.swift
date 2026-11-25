import SwiftUI
import SwiftData

/// The songs for one mood and crowd (design 3A/3B): ready-to-play songs first.
/// The mood can be changed from the header and the crowd from the chip row.
struct SongListScreen: View {
    @State var mood: Mood
    @State var crowd: CrowdFilter

    @Query(sort: \Mood.sortOrder) private var moods: [Mood]
    @Query private var allSongs: [Song]

    @Environment(SheetRouter.self) private var router: SheetRouter?
    /// Shared with Home's language chips.
    @AppStorage("languageFilter") private var language: LanguageFilter = .all

    private var moodSongs: [Song] { MoodLibrary.songs(for: mood, in: allSongs.filtered(by: language)) }

    private var shownSongs: [Song] {
        moodSongs
            .filter { $0.matches(crowd) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        let songs = shownSongs
        let ready = songs.filter(\.isReady)
        let learning = songs.filter { !$0.isReady }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                moodHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 4)

                crowdChips
                    .padding(.top, 16)

                if songs.isEmpty {
                    emptyState
                } else {
                    if !ready.isEmpty { section("Ready to play", ready) }
                    if !learning.isEmpty { section("Still learning", learning) }
                }
            }
            .padding(.bottom, 32)
        }
        .moodGlow(mood.swatch.color)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Language", selection: $language) {
                        ForEach(LanguageFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label(language == .all ? "All languages" : language.title, systemImage: "globe")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel("Language: \(language.title)")
            }
        }
        .hidesTabBar()
    }

    // MARK: Header

    /// The mood icon and name; tapping opens a menu to switch mood.
    private var moodHeader: some View {
        Menu {
            Picker("Mood", selection: $mood) {
                ForEach(moods) { option in
                    Label(option.name, systemImage: option.symbol).tag(option)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mood.symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.moodInk)
                    .frame(width: 52, height: 52)
                    .background(mood.swatch.color, in: .circle)
                    .environment(\.colorScheme, .light)
                    .accessibilityHidden(true)
                Text(mood.name)
                    .font(Theme.font(size: 38, weight: .heavy))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.fg2)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mood.name), change mood")
        .accessibilityAddTraits(.isHeader)
    }

    /// Anyone, Elders, Friends, Mixed, Kids; the chosen one is inverted with a check mark.
    private var crowdChips: some View {
        let options: [CrowdFilter] = [.anyone] + Crowd.allCases.map { .crowd($0) }
        return ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        crowd = option
                    } label: {
                        Chip(title: option.title, style: option == crowd ? .selected : .option)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Sections

    private func section(_ title: String, _ songs: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SpecLabel(title)
                Spacer()
                SpecLabel(String(songs.count))
            }
            .padding(.horizontal, 8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            SongCard(songs: songs)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }

    // MARK: Empty (3B)

    private var emptyState: some View {
        let empty = SongListEmptyState(mood: mood, crowd: crowd, moodSongs: moodSongs)
        return VStack(spacing: 0) {
            Image(systemName: mood.symbol)
                .font(.system(size: 40))
                .foregroundStyle(Theme.moodInk)
                .frame(width: 96, height: 96)
                .background(mood.swatch.color, in: .circle)
                .environment(\.colorScheme, .light)
                .accessibilityHidden(true)

            Text(empty.title)
                .font(Theme.font(size: 26, weight: .heavy))
                .foregroundStyle(Theme.fg)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
            Text(empty.body)
                .font(Theme.font(size: 16))
                .foregroundStyle(Theme.fg2)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            if let alternative = empty.alternative {
                Button {
                    crowd = alternative.filter
                } label: {
                    Text(alternative.label)
                        .font(Theme.font(.bodyStrong))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 26)
                        .frame(height: 54)
                        .background(Theme.fg, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, 26)
            }

            Button {
                router?.addSong()
            } label: {
                Label("Add a song", systemImage: "plus")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundStyle(Theme.chord)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 36)
        .padding(.top, 72)
    }
}

/// The words and the "try another crowd" button for an empty song list.
struct SongListEmptyState {
    struct Alternative: Equatable {
        var label: String
        var filter: CrowdFilter
    }

    var title: String
    var body: String
    var alternative: Alternative?

    init(mood: Mood, crowd: CrowdFilter, moodSongs: [Song]) {
        let count = moodSongs.count
        switch crowd {
        case .anyone:
            title = "No \(mood.name) songs yet"
            body = "Add a song and tag it \(mood.name)."
            alternative = nil
        case .crowd(let picked):
            title = "No \(mood.name) songs for \(picked.title) yet"
            if count == 0 {
                body = "Add a song and tag it \(mood.name)."
                alternative = nil
            } else {
                body = "\(mood.name) has \(CrowdSheet.songCount(count)), just not for this crowd."
                // Suggest the first crowd that does have songs, else show them all.
                if let other = Crowd.allCases.first(where: { c in moodSongs.contains { $0.matches(.crowd(c)) } }) {
                    alternative = Alternative(label: "Show for \(other.title)", filter: .crowd(other))
                } else {
                    alternative = Alternative(label: "Show all crowds", filter: .anyone)
                }
            }
        }
    }
}

#if DEBUG
private struct SongListPreview: View {
    var moodName: String
    var crowd: CrowdFilter
    @Query private var moods: [Mood]

    var body: some View {
        if let mood = moods.first(where: { $0.name == moodName }) {
            NavigationStack {
                SongListScreen(mood: mood, crowd: crowd)
            }
        }
    }
}

#Preview("3A · Romantic · Mixed", traits: .sampleLibrary) {
    SongListPreview(moodName: "Romantic", crowd: .crowd(.mixed))
}

#Preview("3A · Dark", traits: .sampleLibrary) {
    SongListPreview(moodName: "Romantic", crowd: .crowd(.mixed))
        .preferredColorScheme(.dark)
}

#Preview("3B · No songs for crowd", traits: .sampleLibrary) {
    SongListPreview(moodName: "Campfire", crowd: .crowd(.elders))
}
#endif
