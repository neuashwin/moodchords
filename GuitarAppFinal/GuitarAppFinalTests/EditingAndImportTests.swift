//
//  EditingAndImportTests.swift
//  MoodchordsTests
//

import Foundation
import SwiftData
import Testing
@testable import GuitarAppFinal

struct SourceEditingTests {
    let source = """
    {title: Campfire Night}
    {key: G}
    {mood: Campfire, Jolly}

    {start_of_verse}
    [G]Sparks are rising [C]up into the [G]sky
    """

    @Test func readsValuesAndAliases() {
        #expect(SourceEditing.value(of: .title, in: source) == "Campfire Night")
        #expect(SourceEditing.value(of: .title, in: "{t: Short}") == "Short")
        #expect(SourceEditing.value(of: .artist, in: source) == nil)
        #expect(SourceEditing.list(of: .mood, in: source) == ["Campfire", "Jolly"])
    }

    @Test func replacesExistingLine() {
        let edited = SourceEditing.setting(.key, to: "A", in: source)
        #expect(SourceEditing.value(of: .key, in: edited) == "A")
        #expect(edited.components(separatedBy: "\n").count == source.components(separatedBy: "\n").count)
    }

    @Test func addsMissingDirectiveAfterHeader() {
        let edited = SourceEditing.setting(.artist, to: "Moodchords Sample", in: source)
        let lines = edited.components(separatedBy: "\n")
        #expect(lines[3] == "{artist: Moodchords Sample}")
        #expect(lines[5] == "{start_of_verse}")
    }

    @Test func emptyValueRemovesDirective() {
        let edited = SourceEditing.setting(.key, to: "  ", in: source)
        #expect(SourceEditing.value(of: .key, in: edited) == nil)
        #expect(!edited.contains("{key"))
    }

    @Test func removesDuplicateDirectives() {
        let edited = SourceEditing.setting(.key, to: "D", in: "{title: X}\n{key: G}\n{key: A}")
        #expect(edited == "{title: X}\n{key: D}")
    }

    @Test func setsListsAndKeepsLyrics() throws {
        let edited = SourceEditing.setting(.crowd, toList: ["Friends", "Kids"], in: source)
        let parsed = try ChordProParser.parse(edited)
        #expect(parsed.crowds == ["Friends", "Kids"])
        #expect(edited.contains("[G]Sparks are rising"))
    }

    @Test func bracedLyricIsNotTreatedAsDirective() {
        let text = "{title: X}\n{Sparks are rising,"
        #expect(SourceEditing.setting(.key, to: "G", in: text) == "{title: X}\n{key: G}\n{Sparks are rising,")
    }
}

@MainActor
struct SongUpdateAndImportTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Song.self, Mood.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func updateRefreshesFieldsAndKeepsMarks() throws {
        let original = "{title: Old}\n{duration: 1:00}\n{mood: Sad}"
        let song = Song(parsed: try ChordProParser.parse(original), source: original)
        song.isFavorite = true
        song.isReady = true
        context.insert(song)

        let edited = "{title: New}\n{artist: Someone}\n{key: Am}\n{duration: 2:30}\n{mood: Romantic}\n{crowd: Kids}"
        song.update(parsed: try ChordProParser.parse(edited), source: edited)

        #expect(song.title == "New")
        #expect(song.artist == "Someone")
        #expect(song.key == "Am")
        #expect(song.durationSeconds == 150)
        #expect(song.moodNames == ["Romantic"])
        #expect(song.crowds == [.kids])
        #expect(song.source == edited)
        #expect(song.isFavorite && song.isReady)
    }

    /// Writes files into a fresh temporary folder.
    private func folder(_ files: [String: String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Jam songs \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for (name, text) in files {
            try text.write(to: url.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return url
    }

    @Test func importsFolderAndReportsChecks() throws {
        let url = try folder([
            "a.txt": "{title: Alpha}\n{key: G}\n{duration: 3:00}\n{mood: Campfire}",
            "b.cho": "{title: Beta}\n{mood: Wedding}",
            "notes.pdf": "not a song",
            "c.txt": "no title here",
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let report = SongImporter.importFiles([url], into: context, knownMoods: ["Campfire"])

        #expect(Set(report.addedTitles) == ["Alpha", "Beta"])
        #expect(report.fileCount == 3)
        #expect(report.folderName?.hasPrefix("Jam songs") == true)
        #expect(report.checks.contains { $0.title == "notes.pdf" && $0.kind == .skipped })
        #expect(report.checks.contains { $0.title == "c.txt" && $0.kind == .problem })
        #expect(report.checks.contains { $0.title == "Beta" && $0.kind == .length })
        #expect(report.checks.contains { $0.title == "Beta" && $0.kind == .key })
        #expect(report.checks.contains { $0.title == "Beta" && $0.kind == .mood && $0.message.contains("Wedding") })
        #expect(!report.checks.contains { $0.title == "Alpha" })
        #expect(try context.fetchCount(FetchDescriptor<Song>()) == 2)
    }

    @Test func importingTheSameFolderTwiceSkipsDuplicates() throws {
        let url = try folder(["a.txt": "{title: Alpha}\n{key: G}\n{duration: 3:00}\n{mood: Campfire}"])
        defer { try? FileManager.default.removeItem(at: url) }

        _ = SongImporter.importFiles([url], into: context, knownMoods: ["Campfire"])
        let second = SongImporter.importFiles([url], into: context, knownMoods: ["Campfire"])

        #expect(second.addedTitles.isEmpty)
        #expect(second.checks.first?.kind == .skipped)
        #expect(try context.fetchCount(FetchDescriptor<Song>()) == 1)
    }

    @Test func importConvertsChordsAboveLyrics() throws {
        let url = try folder(["sheet.txt": "{title: Sheet}\n{mood: Sad}\nG       C\nHello there friend"])
        defer { try? FileManager.default.removeItem(at: url) }

        _ = SongImporter.importFiles([url], into: context, knownMoods: ["Sad"])
        let song = try #require(try context.fetch(FetchDescriptor<Song>()).first)
        #expect(song.source.contains("[G]"))
    }
}

@MainActor
struct MoodManagementTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Song.self, Mood.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        try MoodLibrary.seedDefaultsIfNeeded(in: container.mainContext)
    }

    @Test func addsCustomMoodAtTheEnd() throws {
        let mood = try MoodLibrary.addMood(name: " Hostel nights ", symbol: "moon.stars.fill", hue: 270, in: context)
        #expect(mood.name == "Hostel nights")
        #expect(!mood.isDefault)
        #expect(try MoodLibrary.allMoods(in: context).last?.id == mood.id)
        #expect(mood.sortOrder == 9)
    }

    @Test func rejectsDuplicateOrEmptyNewMood() {
        #expect(throws: MoodLibrary.RenameError.duplicateName) {
            try MoodLibrary.addMood(name: "campfire", symbol: "flame", hue: 1, in: context)
        }
        #expect(throws: MoodLibrary.RenameError.emptyName) {
            try MoodLibrary.addMood(name: "", symbol: "flame", hue: 1, in: context)
        }
    }

    @Test func deletesOnlyCustomMoods() throws {
        let custom = try MoodLibrary.addMood(name: "Hostel", symbol: "bed.double.fill", hue: 270, in: context)
        let campfire = try #require(try MoodLibrary.allMoods(in: context).first { $0.name == "Campfire" })

        #expect(throws: MoodLibrary.DeleteError.isDefault) { try MoodLibrary.delete(campfire, in: context) }
        try MoodLibrary.delete(custom, in: context)

        let names = try MoodLibrary.allMoods(in: context).map(\.name)
        #expect(!names.contains("Hostel"))
        #expect(names.count == 9)
    }

    @Test func reordersMoods() throws {
        // Move Romantic (0) to after Dance (1).
        try MoodLibrary.move(from: [0], to: 2, in: context)
        let moods = try MoodLibrary.allMoods(in: context)
        #expect(moods.prefix(3).map(\.name) == ["Dance", "Romantic", "Jolly"])
        #expect(moods.map(\.sortOrder) == Array(0..<9))
    }

    @Test(arguments: [
        ([0], 2, ["b", "a", "c", "d"]),
        ([3], 0, ["d", "a", "b", "c"]),
        ([0, 1], 4, ["c", "d", "a", "b"]),
        ([2], 2, ["a", "b", "c", "d"]),
    ])
    func movedMatchesSwiftUIRule(source: [Int], destination: Int, expected: [String]) {
        #expect(MoodLibrary.moved(["a", "b", "c", "d"], from: IndexSet(source), to: destination) == expected)
    }

    @Test func updateChangesNameIconAndColour() throws {
        let sad = try #require(try MoodLibrary.allMoods(in: context).first { $0.name == "Sad" })
        try MoodLibrary.update(sad, name: "Blue", symbol: "drop.fill", hue: 230, in: context)
        #expect(sad.name == "Blue")
        #expect(sad.symbol == "drop.fill")
        #expect(sad.hue == 230)
    }
}
