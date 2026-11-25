import SwiftUI
import SwiftData

/// The song page (design 04): tags, title, Ready switch, the cue card ("how does it start?"),
/// the chord chart, a Play button, and the whole chord sheet.
struct SongScreen: View {
    var song: Song
    /// Captured up front, so we can check whether the song still exists without reading it.
    private let songID: PersistentIdentifier

    @Environment(SheetRouter.self) private var router: SheetRouter?
    @Environment(\.dismiss) private var dismiss
    /// Watched so the page notices when its song is deleted (e.g. from the editor).
    @Query private var allSongs: [Song]
    @Query(sort: \Mood.sortOrder) private var moods: [Mood]

    @State private var isPlaying = false

    init(song: Song) {
        self.song = song
        songID = song.persistentModelID
    }

    var body: some View {
        // A deleted song must not be read again (SwiftData would crash), so go back.
        if allSongs.contains(where: { $0.persistentModelID == songID }) {
            content
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private var content: some View {
        let parsed = try? ChordProParser.parse(song.source)
        let summary = song.summary
        let songMoods = moods.filter { song.hasMood(named: $0.name) }
        let chords = (parsed?.chords ?? []).filter(ChordSheetConverter.isChord)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                tags(moods: songMoods)

                // Full width for the title (long titles would be squeezed beside the switch).
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .themeFont(.title)
                        .foregroundStyle(Theme.fg)
                        .accessibilityAddTraits(.isHeader)
                    if let artist = song.artist {
                        Text(artist)
                            .themeFont(.body)
                            .foregroundStyle(Theme.fg2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.top, 10)

                readyToggle
                    .padding(.top, 12)
                    .padding(.horizontal, 6)

                cueCard(summary: summary, parsed: parsed)
                    .padding(.top, 14)

                if summary.capo != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .accessibilityHidden(true)
                        Text("Tune before putting the capo on.")
                        Button("Tuner") { router?.requestedTab = .tuner }
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.chord)
                    }
                    .font(Theme.font(size: 14))
                    .foregroundStyle(Theme.fg2)
                    .padding(.top, 10)
                    .padding(.horizontal, 6)
                }

                if !chords.isEmpty {
                    SpecLabel(chords.count == 1 ? "1 chord" : "\(chords.count) chords")
                        .padding(.top, 20)
                        .padding(.horizontal, 6)
                    ChordChart(chords: chords)
                        .padding(.top, 10)
                }

                AccentCapsuleButton(title: "Play", symbol: "play.fill") { isPlaying = true }
                    .padding(.top, 22)

                if let parsed {
                    ChordSheetView(lines: parsed.lines)
                        .tint(Theme.chord)
                        .padding(.top, 26)
                        .padding(.horizontal, 6)
                } else {
                    Text("This song's text couldn't be read. Edit it to fix it.")
                        .themeFont(.body)
                        .foregroundStyle(Theme.danger)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .moodGlow(songMoods.first?.swatch.color ?? Color(moodHue: 50))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(song.isFavorite ? "Unfavourite" : "Favourite",
                       systemImage: song.isFavorite ? "star.fill" : "star") {
                    song.isFavorite.toggle()
                }
                .tint(song.isFavorite ? Theme.chord : nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { router?.edit(song) }
            }
        }
        .fullScreenCover(isPresented: $isPlaying) {
            PlayScreen(song: song)
        }
        .hidesTabBar()
    }

    // MARK: Pieces

    private func tags(moods: [Mood]) -> some View {
        FlowLayout(rowSpacing: 6, itemSpacing: 6) {
            ForEach(moods) { mood in
                Chip(title: mood.name, style: .mood(mood.swatch))
            }
            ForEach(song.crowds) { crowd in
                Chip(title: crowd.title)
            }
            if let language = song.songLanguage {
                Chip(title: language.title)
            }
        }
        .padding(.horizontal, 6)
    }

    private var readyToggle: some View {
        Toggle(isOn: Binding(get: { song.isReady }, set: { song.isReady = $0 })) {
            Text("Ready")
                .font(Theme.font(size: 13, weight: .bold))
                .foregroundStyle(Theme.fg)
        }
        .toggleStyle(.switch)
        .tint(Theme.ok)
        .fixedSize()
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 44)
        .background(Theme.chip, in: .capsule)
    }

    /// Key, capo and length big and clear, then the first line with its chords.
    private func cueCard(summary: SongSummary, parsed: ParsedSong?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SpecLabel("Cue card")
            HStack(alignment: .top) {
                cueValue("Key", summary.key ?? "—")
                cueValue("Capo", summary.capo.map { "Fret \($0)" } ?? "None")
                cueValue("Length", summary.duration.map(SongSummary.formatDuration)
                         ?? "~" + SongSummary.formatDuration(ParsedSong.defaultDuration))
            }
            .padding(.top, 10)

            if let firstLine = firstLyricLine(parsed) {
                Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 12)
                SpecLabel("Starts")
                ChordLineView(segments: firstLine, fontSize: 19, textColor: Theme.fg, chordColor: Theme.chord)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 30))
        .overlay { RoundedRectangle(cornerRadius: 30).strokeBorder(Theme.line, lineWidth: 0.5) }
    }

    private func cueValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            SpecLabel(label)
            Text(value)
                .font(Theme.font(size: 28, weight: .heavy))
                .foregroundStyle(Theme.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The first line with words in it (chord-only intro lines are skipped).
    private func firstLyricLine(_ parsed: ParsedSong?) -> [ChordSegment]? {
        for case .lyrics(let segments) in parsed?.lines ?? [] {
            if segments.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
                return segments
            }
        }
        return nil
    }
}
