//
//  CapoCrowdDirectiveTests.swift
//  MoodchordsTests
//

import Testing
@testable import GuitarAppFinal

struct CapoCrowdDirectiveTests {

    @Test func parsesCrowdTags() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n{crowd: Elders, mixed, Mixed, Kids}")
        #expect(song.crowds == ["Elders", "mixed", "Kids"])
        #expect(song.warnings.isEmpty)
    }

    @Test(arguments: [("2", 2), ("2nd fret", 2), ("7", 7), ("none", 0), ("No capo", 0)])
    func parsesCapo(input: String, expected: Int) {
        #expect(ChordProParser.parseCapo(input) == expected)
    }

    @Test func capoZeroMeansNoCapo() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n{capo: none}")
        #expect(song.capo == nil)
        #expect(song.warnings.isEmpty)
    }

    @Test func badCapoWarns() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n{capo: high}")
        #expect(song.capo == nil)
        #expect(song.warnings.contains { $0.line == 3 })
    }
}

struct BracedLyricTests {

    @Test func bracedLyricLineIsKeptAsLyrics() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n{Sparks are rising, up and away,")
        #expect(song.lines == [.lyrics([ChordSegment(chord: nil, text: "{Sparks are rising, up and away,")])])
        #expect(song.warnings.isEmpty)
    }

    @Test func bracedLyricAfterChordLineIsMerged() throws {
        let sheet = "{title: X}\n{duration: 1:00}\nG\n{Sing it loud"
        let song = try ChordProParser.parse(ChordSheetConverter.convertIfNeeded(sheet))
        #expect(song.lines == [.lyrics([ChordSegment(chord: "G", text: "{Sing it loud")])])
    }

    @Test(arguments: ["{title: X}", "{soc}", "{duration: 4:30", "{ start_of_chorus }"])
    func directivesStillRecognised(line: String) {
        #expect(ChordProParser.looksLikeDirective(line))
    }

    @Test(arguments: ["{Sparks are rising,", "{La la la}", "{2x}"])
    func lyricsInBracesAreNotDirectives(line: String) {
        #expect(!ChordProParser.looksLikeDirective(line))
    }
}
