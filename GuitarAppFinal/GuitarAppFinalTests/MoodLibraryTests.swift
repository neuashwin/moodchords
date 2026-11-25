//
//  MoodLibraryTests.swift
//  MoodchordsTests
//

import Foundation
import SwiftData
import Testing
@testable import GuitarAppFinal

@MainActor
struct MoodLibraryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Song.self, Mood.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A lyric-free song stub with the given tags.
    @discardableResult
    func addSong(_ title: String, moods: [String], crowds: [String] = []) throws -> Song {
        var source = "{title: \(title)}\n{duration: 1:00}\n{mood: \(moods.joined(separator: ", "))}"
        if !crowds.isEmpty { source += "\n{crowd: \(crowds.joined(separator: ", "))}" }
        let song = Song(parsed: try ChordProParser.parse(source), source: source)
        context.insert(song)
        return song
    }

    // MARK: Seeding

    @Test func seedsNineDefaultsInOrder() throws {
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        let moods = try MoodLibrary.allMoods(in: context)
        #expect(moods.map(\.name) == ["Romantic", "Dance", "Jolly", "Campfire", "Sad",
                                      "Devotional", "Nostalgic", "Party", "Festival"])
        #expect(moods.allSatisfy { $0.isDefault })
        #expect(moods.map(\.sortOrder) == Array(0..<9))
        #expect(moods.last?.subtitle == "Dashain · Tihar")
    }

    @Test func seedingTwiceDoesNotDuplicate() throws {
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        #expect(try context.fetchCount(FetchDescriptor<Mood>()) == 9)
    }

    @Test func doesNotSeedOverExistingMoods() throws {
        context.insert(Mood(name: "Hostel", symbol: "bed.double.fill", hue: 270, sortOrder: 0))
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        #expect(try MoodLibrary.allMoods(in: context).map(\.name) == ["Hostel"])
    }

    // MARK: Matching

    @Test func matchesIgnoringCaseAndSpaces() throws {
        let mood = Mood(name: "Campfire", symbol: "flame.fill", hue: 50, sortOrder: 0)
        #expect(mood.matches(name: "campfire"))
        #expect(mood.matches(name: " CAMPFIRE "))
        #expect(!mood.matches(name: "Camp fire"))
    }

    @Test func findsSongsForMood() throws {
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        try addSong("Campfire Night", moods: ["campfire", "Jolly"])
        try addSong("साँझको गीत", moods: ["Romantic"])
        let songs = try context.fetch(FetchDescriptor<Song>())
        let moods = try MoodLibrary.allMoods(in: context)
        let campfire = try #require(moods.first { $0.name == "Campfire" })
        let romantic = try #require(moods.first { $0.name == "Romantic" })

        #expect(MoodLibrary.songs(for: campfire, in: songs).map(\.title) == ["Campfire Night"])
        #expect(MoodLibrary.songs(for: romantic, in: songs).map(\.title) == ["साँझको गीत"])
    }

    @Test func devanagariMoodNamesMatch() {
        let mood = Mood(name: "साँझ", symbol: "moon.fill", hue: 280, sortOrder: 0)
        #expect(mood.matches(name: " साँझ"))
        // Folding is case-only: a missing candrabindu is a different word.
        #expect(!mood.matches(name: "सांझ"))
    }

    // MARK: Rename

    @Test func renameUpdatesSongs() throws {
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        let tagged = try addSong("Campfire Night", moods: ["campfire", "Jolly"])
        let other = try addSong("Other", moods: ["Sad"])
        let campfire = try #require(try MoodLibrary.allMoods(in: context).first { $0.name == "Campfire" })

        try MoodLibrary.rename(campfire, to: "  Bonfire ", in: context)

        #expect(campfire.name == "Bonfire")
        #expect(tagged.moodNames == ["Bonfire", "Jolly"])
        #expect(other.moodNames == ["Sad"])
        #expect(MoodLibrary.songs(for: campfire, in: [tagged, other]).count == 1)
    }

    @Test func renameRejectsDuplicateAndEmpty() throws {
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        let campfire = try #require(try MoodLibrary.allMoods(in: context).first { $0.name == "Campfire" })

        #expect(throws: MoodLibrary.RenameError.duplicateName) {
            try MoodLibrary.rename(campfire, to: "party", in: context)
        }
        #expect(throws: MoodLibrary.RenameError.emptyName) {
            try MoodLibrary.rename(campfire, to: "   ", in: context)
        }
        #expect(campfire.name == "Campfire")
    }

    @Test func renameCanChangeJustTheCase() throws {
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        let song = try addSong("X", moods: ["Sad"])
        let sad = try #require(try MoodLibrary.allMoods(in: context).first { $0.name == "Sad" })
        try MoodLibrary.rename(sad, to: "SAD", in: context)
        #expect(sad.name == "SAD")
        #expect(song.moodNames == ["SAD"])
    }

    @Test func renamedTagsDoesNotDuplicate() {
        #expect(MoodLibrary.renamedTags(["Campfire", "Bonfire", "Jolly"], from: "campfire", to: "Bonfire")
                == ["Bonfire", "Jolly"])
    }

    @Test(arguments: [(0, "No songs yet"), (1, "1 song"), (12, "12 songs")])
    func tileCountLabel(count: Int, expected: String) {
        #expect(MoodTile.countLabel(for: count) == expected)
    }

    // MARK: Song flags and crowds

    @Test func newSongIsNotReady() throws {
        #expect(try addSong("X", moods: ["Sad"]).isReady == false)
    }

    @Test func filtersMoodSongsByCrowd() throws {
        try MoodLibrary.seedDefaultsIfNeeded(in: context)
        try addSong("A", moods: ["Campfire"], crowds: ["Friends", "Kids"])
        try addSong("B", moods: ["campfire"], crowds: ["Elders"])
        try addSong("C", moods: ["Campfire"])                      // no crowd tags
        try addSong("D", moods: ["Sad"], crowds: ["Friends"])      // other mood
        let songs = try context.fetch(FetchDescriptor<Song>())
        let campfire = try #require(try MoodLibrary.allMoods(in: context).first { $0.name == "Campfire" })

        func titles(_ filter: CrowdFilter) -> Set<String> {
            Set(MoodLibrary.songs(for: campfire, in: songs, crowd: filter).map(\.title))
        }
        #expect(titles(.anyone) == ["A", "B", "C"])
        #expect(titles(.crowd(.friends)) == ["A"])
        #expect(titles(.crowd(.elders)) == ["B"])
        #expect(titles(.crowd(.mixed)).isEmpty)
    }

    @Test(arguments: [(0, "0 songs"), (1, "1 song"), (5, "5 songs")])
    func crowdSheetSongCount(count: Int, expected: String) {
        #expect(CrowdSheet.songCount(count) == expected)
    }

    @Test func readsCrowdsIgnoringCaseAndUnknowns() throws {
        let song = try addSong("X", moods: ["Sad"], crowds: ["mixed", "Kids", "Aliens", "MIXED"])
        #expect(song.crowds == [.mixed, .kids])
    }
}
