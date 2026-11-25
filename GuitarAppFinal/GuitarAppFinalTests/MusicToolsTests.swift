//
//  MusicToolsTests.swift
//  MoodchordsTests
//

import Foundation
import SwiftData
import Testing
@testable import GuitarAppFinal

struct ChordShapeTests {
    @Test(arguments: [
        ("C", "x32010"), ("G", "320003"), ("Am", "x02210"), ("Em7", "022030"), ("Dsus4", "xx0233"),
        ("G/B", "x20003"), ("F", "133211"), ("Bm", "x24432"),
        // Built from movable shapes
        ("Bb", "x13331"), ("C#m", "x46654"), ("F#m7", "242222"), ("Ab", "466544"),
        ("Fm", "133111"), ("Ebmaj7", "x68786"), ("C9", "x32333"), ("Bdim", "x2343x"),
    ])
    func knownShapes(name: String, tab: String) throws {
        #expect(try #require(ChordShapes.shape(for: name)).tab == tab)
    }

    @Test func barreChordsAreMarked() throws {
        #expect(try #require(ChordShapes.shape(for: "Bb")).barre == 1)
        #expect(try #require(ChordShapes.shape(for: "C#m")).barre == 4)
        #expect(try #require(ChordShapes.shape(for: "C")).barre == nil)
    }

    @Test func slashChordFallsBackToMainChord() throws {
        let slash = try #require(ChordShapes.shape(for: "F#m/E"))
        let plain = try #require(ChordShapes.shape(for: "F#m"))
        #expect(slash.tab == plain.tab)
    }

    @Test func flatsAndSharpsAreTheSameChord() throws {
        #expect(ChordShapes.shape(for: "Db")?.tab == ChordShapes.shape(for: "C#")?.tab)
    }

    @Test(arguments: ["N.C.", "H", "", "Intro"])
    func notChords(name: String) {
        #expect(ChordShapes.shape(for: name) == nil)
    }

    @Test func chordNameParts() throws {
        let chord = try #require(ChordName("F#m7/E"))
        #expect(chord.root == 6)
        #expect(chord.quality == "m7")
        #expect(chord.bass == 4)
    }
}

struct PitchDetectorTests {
    /// A plucked-string-like tone: fundamental plus two weaker harmonics.
    private func tone(_ frequency: Double, sampleRate: Double = 48_000, count: Int = 4096) -> [Float] {
        (0..<count).map { i in
            let t = Double(i) / sampleRate
            let wave = sin(2 * .pi * frequency * t) + 0.5 * sin(4 * .pi * frequency * t) + 0.25 * sin(6 * .pi * frequency * t)
            return Float(0.3 * wave)
        }
    }

    @Test(arguments: [82.41, 110.0, 146.83, 196.0, 246.94, 329.63, 105.0])
    func detectsGuitarPitches(frequency: Double) throws {
        let detector = PitchDetector(sampleRate: 48_000)
        let detected = try #require(detector.pitch(of: tone(frequency)))
        #expect(abs(Tuning.cents(detected, from: frequency)) < 3, "got \(detected) for \(frequency)")
    }

    @Test func silenceHasNoPitch() {
        #expect(PitchDetector(sampleRate: 48_000).pitch(of: [Float](repeating: 0, count: 4096)) == nil)
    }

    @Test func nearestStringAndCents() {
        #expect(Tuning.nearestString(to: 106.4).note == "A")
        #expect(Tuning.nearestString(to: 106.4).number == 5)
        #expect(Tuning.cents(106.4, from: 110) < -50)
        #expect(abs(Tuning.cents(110, from: 110)) < 0.001)
        #expect(Tuning.nearestString(to: 80).number == 6)
        #expect(Tuning.noteName(for: 440) == "A")
        #expect(Tuning.noteName(for: 277.18) == "C#")
    }
}

@MainActor
struct LanguageTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Song.self, Mood.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func folder(_ files: [String: String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Songs \(UUID().uuidString)")
        for (path, text) in files {
            let file = url.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        }
        return url
    }

    @Test func importTakesLanguageFromFolderName() throws {
        let url = try folder([
            "Nepali/a.txt": "{title: Alpha}\n{mood: Sad}",
            "English/b.txt": "{title: Beta}\n{mood: Sad}",
            "Hindi/c.txt": "{title: Gamma}\n{mood: Sad}\n{language: English}",   // file's own tag wins
            "Other/d.txt": "{title: Delta}\n{mood: Sad}",
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        _ = SongImporter.importFiles([url], into: context, knownMoods: ["Sad"])
        let songs = try context.fetch(FetchDescriptor<Song>())
        func language(_ title: String) -> SongLanguage? { songs.first { $0.title == title }?.songLanguage }
        #expect(language("Alpha") == .nepali)
        #expect(language("Beta") == .english)
        #expect(language("Gamma") == .english)
        #expect(language("Delta") == nil)
        #expect(songs.first { $0.title == "Alpha" }?.source.contains("{language: Nepali}") == true)
    }

    @Test func reimportFillsMissingLanguageWithoutDuplicating() throws {
        // Imported before languages existed: no {language:} line.
        let text = "{title: Alpha}\n{mood: Sad}\n[G]Hello"
        let song = Song(parsed: try ChordProParser.parse(text), source: text)
        song.isFavorite = true
        context.insert(song)

        let url = try folder(["Nepali/a.txt": text])
        defer { try? FileManager.default.removeItem(at: url) }
        let report = SongImporter.importFiles([url], into: context, knownMoods: ["Sad"])

        #expect(report.addedTitles.isEmpty)
        #expect(report.languageUpdates == 1)
        #expect(try context.fetchCount(FetchDescriptor<Song>()) == 1)
        #expect(song.songLanguage == .nepali)
        #expect(song.isFavorite)
    }

    @Test func duplicateGetsLanguageFromIncomingFileText() throws {
        // Already in the library without a language; the built-in copy has one.
        let text = "{title: Alpha}\n{mood: Sad}\n[G]Hello"
        let song = Song(parsed: try ChordProParser.parse(text), source: text)
        context.insert(song)

        let url = try folder(["BundledSong-Hindi-Alpha.txt": "{title: Alpha}\n{mood: Sad}\n{language: Hindi}\n[G]Hello"])
        defer { try? FileManager.default.removeItem(at: url) }
        let file = url.appendingPathComponent("BundledSong-Hindi-Alpha.txt")
        let report = SongImporter.importFiles([file], into: context, knownMoods: ["Sad"])

        #expect(report.addedTitles.isEmpty)
        #expect(report.languageUpdates == 1)
        #expect(song.songLanguage == .hindi)
        #expect(try context.fetchCount(FetchDescriptor<Song>()) == 1)
    }

    @Test func filterKeepsMatchingLanguages() throws {
        let songs = try ["English", "Nepali", "Hindi"].map { name in
            let text = "{title: \(name) song}\n{language: \(name)}"
            let song = Song(parsed: try ChordProParser.parse(text), source: text)
            context.insert(song)
            return song
        } + [Song(parsed: try ChordProParser.parse("{title: Untagged}"), source: "{title: Untagged}")]

        #expect(songs.filtered(by: .all).count == 4)
        #expect(songs.filtered(by: .nepali).map(\.title) == ["Nepali song"])
        #expect(songs.filtered(by: .hindi).map(\.title) == ["Hindi song"])
    }

    @Test func newSongsPlayAtNormalSpeed() throws {
        #expect(Song(parsed: try ChordProParser.parse("{title: X}"), source: "{title: X}").scrollSpeed == 1)
    }
}
