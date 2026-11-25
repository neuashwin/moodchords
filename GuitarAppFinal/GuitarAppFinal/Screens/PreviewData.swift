#if DEBUG
import SwiftUI
import SwiftData

/// In-memory databases for SwiftUI previews.
///
/// Only the two original sample songs are used, and only their tags (no lyrics):
/// real songs must never appear in code, previews or tests.
enum PreviewData {
    /// A fresh in-memory library with the default moods and, optionally, the sample songs.
    static func container(withSongs: Bool = true) -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: Song.self, Mood.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = container.mainContext
            try MoodLibrary.seedDefaultsIfNeeded(in: context)
            if withSongs {
                for (text, ready) in sampleSongs {
                    // Converted like a real import, so the website-style sample gets inline chords.
                    let source = ChordSheetConverter.convertIfNeeded(text)
                    let song = Song(parsed: try ChordProParser.parse(source), source: source)
                    song.isReady = ready
                    // One favourite, so the Favourites tab has something to show.
                    song.isFavorite = song.title == "Campfire Night"
                    context.insert(song)
                }
                try context.save()
            }
            return container
        } catch {
            fatalError("Preview data failed: \(error)")
        }
    }

    /// True when the app was launched with `-UseSampleData` (developer testing only): the app
    /// then runs on a throwaway in-memory library with the sample songs, leaving the real one untouched.
    static var isRequestedAtLaunch: Bool {
        CommandLine.arguments.contains("-UseSampleData")
    }

    /// The two original sample songs from `design-prompt.md` (source text, ready to play?),
    /// plus a romanized-title stub of the second one, to test Devanagari and romanized titles together.
    private static let sampleSongs: [(String, Bool)] = [
        ("""
        {title: Campfire Night}
        {artist: Moodchords Sample}
        {key: G}
        {duration: 2:45}
        {mood: Campfire, Jolly}
        {crowd: Friends, Mixed, Kids}
        {language: English}
        {start_of_verse}
        [G]Sparks are rising [C]up into the [G]sky
        [Em]Friends around the [C]fire and the [D]night rolls by
        {end_of_verse}
        {start_of_chorus}
        [C]Sing it loud, [G]sing it slow
        [D]Every song we [G]used to know
        {end_of_chorus}
        {start_of_verse}
        [G]Someone's got a [C]story, someone's [G]got a tune
        [Em]Strumming till the [C]morning chases [D]off the moon
        {end_of_verse}
        """, true),
        ("""
        {title: साँझको गीत}
        {artist: Moodchords Sample}
        {key: Am}
        {duration: 3:10}
        {mood: Romantic, Nostalgic}
        {crowd: Elders, Mixed}
        {language: Nepali}
        {start_of_verse}
        [Am]साँझ परेपछि [F]पहाड हेर्छु
        [C]तिम्रो याद [G]मनमा बोक्छु
        [Am]Saanjh parepachhi [F]pahad herchhu
        {end_of_verse}
        {start_of_chorus}
        [F]बिस्तारै [G]बिस्तारै
        [Am]गीत यो [G]गाउँछु [Am]म
        {end_of_chorus}
        """, false),
        ("""
        {title: Saanjhko Geet}
        {artist: Moodchords Sample}
        {key: Am}
        {capo: 2}
        {mood: Romantic}
        {crowd: Friends, Mixed}
        {language: Nepali}
        [Am]Saanjh parepachhi [F]pahad herchhu
        """, true),
        // Laid out like a chord-website page, to test formatting: notes, [Intro], chords above
        // the lyrics (some past the end of the line), long lines. Sample-song words only.
        ("""
        {title: Campfire Night (website layout)}
        {artist: Moodchords Sample}
        {key: C#m}
        {mood: Dance}
        {crowd: Friends}
        {language: English}

        CLICK TRANSPOSE FOR EASIER OPEN CHORDS WITH CAPO ON 4TH FRET
        VIDEO LESSON - https://example.com/lesson
        N.C. means no chord played

        [Intro]
        C#m F#m A B
        C#m F#m A B

        [Verse 1]
            C#m                 F#m
        Sparks are rising up into the sky and the night rolls by
               A              B
        Friends around the fire and the night rolls by
        C#m                      F#m                         A
        Someone's got a story, someone's got a tune, strumming till the morning

        [Chorus]
        A                      B                 C#m
        Sing it loud, sing it slow, every song we used to know
        """, false),
    ]
}

/// Preview trait: `#Preview(traits: .sampleLibrary)` gives the preview the sample library.
struct SampleLibrary: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        PreviewData.container()
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleLibrary: Self { .modifier(SampleLibrary()) }
}
#endif
