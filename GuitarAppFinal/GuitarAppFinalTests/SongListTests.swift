//
//  SongListTests.swift
//  MoodchordsTests
//

import Foundation
import SwiftData
import Testing
@testable import GuitarAppFinal

struct SongSummaryTests {
    private func summary(_ body: String) throws -> SongSummary {
        SongSummary(parsed: try ChordProParser.parse("{title: X}\n" + body))
    }

    @Test func metaLineWithKeyCapoAndLength() throws {
        #expect(try summary("{key: G}\n{capo: 2}\n{duration: 2:45}").metaLine == "G · CAPO 2 · 2:45")
    }

    @Test func metaLineMarksUnknownKeyAndAssumedLength() throws {
        #expect(try summary("").metaLine == "KEY ? · ~3:30")
    }

    @Test func noCapoIsLeftOut() throws {
        #expect(try summary("{key: Am}\n{capo: none}\n{duration: 3:10}").metaLine == "Am · 3:10")
    }

    @Test func cueIsFirstLyricLineWithoutChords() throws {
        let s = try summary("{start_of_verse}\n[G]Sparks are rising [C]up into the [G]sky\n[Em]Friends")
        #expect(s.cueLine == "Sparks are rising up into the sky")
    }

    @Test func cueKeepsDevanagari() throws {
        #expect(try summary("[Am]साँझ परेपछि [F]पहाड हेर्छु").cueLine == "साँझ परेपछि पहाड हेर्छु")
    }

    @Test func cueFallsBackToOpeningChords() throws {
        #expect(try summary("[G] [C] [D] [Em] [Am]").cueLine == "Starts on G · C · D · Em")
    }

    @Test func cueWhenNothingToShow() throws {
        #expect(try summary("{key: G}").cueLine == "No cue yet. Add how it starts.")
    }

    @Test func unreadableSourceGivesEmptySummary() {
        #expect(SongSummary(source: "").metaLine == "KEY ? · ~3:30")
    }
}

@MainActor
struct SongListEmptyStateTests {
    let container: ModelContainer
    let campfire = Mood(name: "Campfire", symbol: "flame.fill", hue: 50, sortOrder: 0)

    init() throws {
        container = try ModelContainer(
            for: Song.self, Mood.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func song(crowds: String) throws -> Song {
        let source = "{title: X}\n{mood: Campfire}\n{crowd: \(crowds)}"
        let song = Song(parsed: try ChordProParser.parse(source), source: source)
        container.mainContext.insert(song)
        return song
    }

    @Test func suggestsACrowdThatHasSongs() throws {
        let songs = [try song(crowds: "Friends")]
        let empty = SongListEmptyState(mood: campfire, crowd: .crowd(.elders), moodSongs: songs)
        #expect(empty.title == "No Campfire songs for Elders yet")
        #expect(empty.body == "Campfire has 1 song, just not for this crowd.")
        #expect(empty.alternative == .init(label: "Show for Friends", filter: .crowd(.friends)))
    }

    @Test func fallsBackToAllCrowdsForUntaggedSongs() throws {
        let songs = [try song(crowds: "")]
        let empty = SongListEmptyState(mood: campfire, crowd: .crowd(.kids), moodSongs: songs)
        #expect(empty.alternative == .init(label: "Show all crowds", filter: .anyone))
    }

    @Test func moodWithNoSongsAtAll() {
        let empty = SongListEmptyState(mood: campfire, crowd: .anyone, moodSongs: [])
        #expect(empty.title == "No Campfire songs yet")
        #expect(empty.body == "Add a song and tag it Campfire.")
        #expect(empty.alternative == nil)
    }
}
