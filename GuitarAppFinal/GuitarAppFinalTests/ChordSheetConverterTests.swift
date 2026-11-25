//
//  ChordSheetConverterTests.swift
//  MoodchordsTests
//

import Foundation
import Testing
@testable import GuitarAppFinal

struct ChordSheetConverterTests {

    @Test func mergesChordLineIntoLyricsByColumn() {
        let merged = ChordSheetConverter.merge(chordLine: "G" + String(repeating: " ", count: 10) + "C", lyricLine: "Sparks are rising up")
        #expect(merged == "[G]Sparks are [C]rising up")
    }

    @Test func chordPastEndOfLyricsIsPadded() {
        let merged = ChordSheetConverter.merge(chordLine: "G      D", lyricLine: "Hey")
        #expect(merged == "[G]Hey    [D]")
    }

    @Test func mergesOverDevanagari() {
        let merged = ChordSheetConverter.merge(chordLine: "Am   F", lyricLine: "साँझ परेपछि")
        #expect(merged.hasPrefix("[Am]"))
        #expect(merged.contains("[F]"))
        #expect(merged.replacingOccurrences(of: "[Am]", with: "").replacingOccurrences(of: "[F]", with: "") == "साँझ परेपछि")
    }

    @Test func convertsWholeSheet() {
        let sheet = """
        {title: Campfire Night}
        Em7   0-2-2-0-3-3
        G     320003

        [Intro]
        Em7  G  Dsus4 | x2

        [Verse 1]
        G                 C
        Sparks are rising up
        e|---0---3---|
        """
        let converted = ChordSheetConverter.convertIfNeeded(sheet)
        #expect(converted == """
        {title: Campfire Night}

        {comment: Intro}
        [Em7] [G] [Dsus4]

        {comment: Verse 1}
        [G]Sparks are rising [C]up
        """)
    }

    @Test func leavesInlineChordProUntouched() {
        let song = "{title: X}\n[Verse]\n[G]Hello [C]world"
        #expect(ChordSheetConverter.convertIfNeeded(song) == song)
    }

    @Test func leavesPlainLyricsUntouched() {
        let text = "{title: X}\nJust words here\nAnd more words"
        #expect(ChordSheetConverter.convertIfNeeded(text) == text)
    }

    @Test(arguments: ["G", "Am", "F#m7", "Bb", "Cadd9", "Dsus4", "A7sus4", "G/F#", "Bm7b5", "Cmaj7", "E7(#9)", "Gdim"])
    func recognisesChords(token: String) {
        #expect(ChordSheetConverter.isChord(token))
    }

    @Test(arguments: ["Hello", "I", "Am I", "Go", "Chorus", "x2"])
    func rejectsNonChords(token: String) {
        #expect(!ChordSheetConverter.isChord(token))
    }

    @Test func lyricLineStartingWithChordLikeWordIsNotAChordLine() {
        #expect(!ChordSheetConverter.isChordLine("A man walks down"))
        #expect(ChordSheetConverter.isChordLine("  G   C  (x2)"))
    }

    @Test func sectionLabels() {
        #expect(ChordSheetConverter.sectionLabel("[Verse 1]") == "Verse 1")
        #expect(ChordSheetConverter.sectionLabel("[Bridge]") == "Bridge")
        #expect(ChordSheetConverter.sectionLabel("[G]") == nil)
    }

    @Test func convertedSheetParses() throws {
        let sheet = "{title: X}\n{duration: 1:00}\n[Chorus]\nC        G\nSing it loud"
        let song = try ChordProParser.parse(ChordSheetConverter.convertIfNeeded(sheet))
        #expect(song.lines == [
            .section("Chorus"),
            .lyrics([ChordSegment(chord: "C", text: "Sing it l"), ChordSegment(chord: "G", text: "oud")]),
        ])
    }
}
