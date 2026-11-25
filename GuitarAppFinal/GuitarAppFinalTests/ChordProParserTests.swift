//
//  ChordProParserTests.swift
//  MoodchordsTests
//

import Testing
@testable import GuitarAppFinal

struct ChordProParserTests {

    // MARK: Metadata

    @Test func parsesMetadata() throws {
        let song = try ChordProParser.parse("""
        {title: Timi Bina}
        {artist: Someone}
        {key: G}
        {duration: 4:30}
        {mood: Romantic, Campfire}
        """)
        #expect(song.title == "Timi Bina")
        #expect(song.artist == "Someone")
        #expect(song.key == "G")
        #expect(song.duration == 270)
        #expect(song.moods == ["Romantic", "Campfire"])
        #expect(song.warnings.isEmpty)
    }

    @Test func shortDirectiveNamesAndCaseInsensitivity() throws {
        let song = try ChordProParser.parse("{T: Short}\n{ST: Artist}\n{DURATION: 200}")
        #expect(song.title == "Short")
        #expect(song.artist == "Artist")
        #expect(song.duration == 200)
    }

    @Test func moodsAreTrimmedAndDeduplicated() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n{mood: Romantic ,  romantic, , Dance}\n{moods: Dance, Sad}")
        #expect(song.moods == ["Romantic", "Dance", "Sad"])
    }

    @Test func missingTitleThrows() {
        #expect(throws: ParseError.missingTitle) {
            try ChordProParser.parse("{duration: 3:00}\n[G]Hello")
        }
    }

    @Test func emptyInputThrows() {
        #expect(throws: ParseError.empty) { try ChordProParser.parse("  \n\n ") }
        #expect(throws: ParseError.empty) { try ChordProParser.parse("\u{FEFF}") }
    }

    @Test func missingDurationWarnsAndFallsBack() throws {
        let song = try ChordProParser.parse("{title: X}")
        #expect(song.duration == nil)
        #expect(song.effectiveDuration == ParsedSong.defaultDuration)
        #expect(song.warnings.count == 1)
    }

    @Test func badDurationWarnsWithLineNumber() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: four minutes}")
        #expect(song.duration == nil)
        #expect(song.warnings.contains { $0.line == 2 && $0.message.contains("four minutes") })
    }

    @Test(arguments: [
        ("4:30", 270), ("0:45", 45), ("270", 270), ("1:02:03", 3723), (" 3:05 ", 185),
    ])
    func validDurations(input: String, expected: Int) {
        #expect(ChordProParser.parseDuration(input) == expected)
    }

    @Test(arguments: ["", "4:60", "abc", "4:", ":30", "0:00", "-1", "1:2:3:4"])
    func invalidDurations(input: String) {
        #expect(ChordProParser.parseDuration(input) == nil)
    }

    @Test func unknownDirectiveWarns() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n{tempo: 120}")
        #expect(song.warnings == [ParseWarning(line: 3, message: "Unknown directive {tempo} was ignored.")])
    }

    @Test func unclosedDirectiveWarns() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00\n")
        #expect(song.duration == nil)
        #expect(song.warnings.contains { $0.line == 2 })
    }

    @Test func handlesBOMAndWindowsLineEndings() throws {
        let song = try ChordProParser.parse("\u{FEFF}{title: X}\r\n{duration: 1:00}\r\n[G]Hi\r\n")
        #expect(song.title == "X")
        #expect(song.lines == [.lyrics([ChordSegment(chord: "G", text: "Hi")])])
    }

    // MARK: Lyrics

    @Test func inlineChordsBecomeSegments() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\nI said [G]Timi bina [C]kehi")
        #expect(song.lines == [.lyrics([
            ChordSegment(chord: nil, text: "I said "),
            ChordSegment(chord: "G", text: "Timi bina "),
            ChordSegment(chord: "C", text: "kehi"),
        ])])
    }

    @Test func chordOnlyLine() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n[G] [C] [D7]")
        #expect(song.lines == [.lyrics([
            ChordSegment(chord: "G", text: " "),
            ChordSegment(chord: "C", text: " "),
            ChordSegment(chord: "D7", text: ""),
        ])])
    }

    @Test func devanagariLyricsStayIntact() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n[Em]तिमी बिना [C]केही पनि [D]छैन")
        #expect(song.lines == [.lyrics([
            ChordSegment(chord: "Em", text: "तिमी बिना "),
            ChordSegment(chord: "C", text: "केही पनि "),
            ChordSegment(chord: "D", text: "छैन"),
        ])])
        #expect(song.warnings.isEmpty)
    }

    @Test func chordBeforeVowelSignIsFound() throws {
        // "]ि" is one Swift Character; the parser must still see the bracket.
        let segments = parse(line: "त[G]िमी")
        #expect(segments.compactMap(\.chord) == ["G"])
        #expect(segments.map(\.text).joined() == "तिमी")
    }

    @Test func chordInsideLetterIsMovedToNextLetter() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\nत[G]िमी")
        #expect(song.lines == [.lyrics([
            ChordSegment(chord: nil, text: "ति"),
            ChordSegment(chord: "G", text: "मी"),
        ])])
        #expect(song.warnings.contains { $0.line == 3 && $0.message.contains("[G]") })
    }

    @Test func chordAfterViramaKeepsLettersWhole() throws {
        let segments = parse(line: "क[Am]्षमा")
        #expect(segments.map(\.text).joined() == "क्षमा")
        #expect(segments.first?.text == "क्")
    }

    @Test func mixedScriptLine() throws {
        let segments = parse(line: "[G]Mero dil [C]मेरो दिल")
        #expect(segments == [
            ChordSegment(chord: "G", text: "Mero dil "),
            ChordSegment(chord: "C", text: "मेरो दिल"),
        ])
    }

    @Test func unclosedBracketIsTreatedAsLyrics() {
        var warnings: [ParseWarning] = []
        let segments = ChordProParser.parseLyricLine("Hello [G world", lineNumber: 5, warnings: &warnings)
        #expect(segments == [ChordSegment(chord: nil, text: "Hello [G world")])
        #expect(warnings.first?.line == 5)
    }

    @Test func emptyBracketsAreIgnored() {
        let segments = parse(line: "Hel[]lo")
        #expect(segments.allSatisfy { $0.chord == nil })
        #expect(segments.map(\.text).joined() == "Hello")
    }

    // MARK: Structure

    @Test func sectionsAndBlankLines() throws {
        let song = try ChordProParser.parse("""
        {title: X}
        {duration: 1:00}


        {comment: Verse 1}
        [G]One


        {start_of_chorus}
        [C]Two
        {end_of_chorus}
        # a note to self

        """)
        #expect(song.lines == [
            .section("Verse 1"),
            .lyrics([ChordSegment(chord: "G", text: "One")]),
            .blank,
            .section("Chorus"),
            .lyrics([ChordSegment(chord: "C", text: "Two")]),
        ])
    }

    @Test func uniqueChordsInOrder() throws {
        let song = try ChordProParser.parse("{title: X}\n{duration: 1:00}\n[G]a [C]b [G]c\n[D]d [C]e")
        #expect(song.chords == ["G", "C", "D"])
    }

    // MARK: Layout pieces

    @Test func piecesSplitAtWordsKeepingChordOnFirst() {
        let pieces = ChordSheetLayout.pieces(from: [
            ChordSegment(chord: nil, text: "I said "),
            ChordSegment(chord: "G", text: "तिमी बिना "),
        ])
        #expect(pieces == [
            ChordSegment(chord: nil, text: "I "),
            ChordSegment(chord: nil, text: "said "),
            ChordSegment(chord: "G", text: "तिमी "),
            ChordSegment(chord: nil, text: "बिना "),
        ])
    }

    @Test func piecesKeepEmptyChordOnlySegment() {
        let pieces = ChordSheetLayout.pieces(from: [ChordSegment(chord: "D7", text: "")])
        #expect(pieces == [ChordSegment(chord: "D7", text: "")])
    }

    @Test func piecesCollapseRunsOfSpaces() {
        // As produced by converting a chord written past the end of a lyric line.
        let pieces = ChordSheetLayout.pieces(from: [
            ChordSegment(chord: "G", text: "Sing it   "),
            ChordSegment(chord: "C", text: "   "),
        ])
        #expect(pieces == [
            ChordSegment(chord: "G", text: "Sing "),
            ChordSegment(chord: nil, text: "it "),
            ChordSegment(chord: "C", text: ""),
        ])
    }

    @Test func leadingSpaceMovesToPreviousWord() {
        let pieces = ChordSheetLayout.pieces(from: [
            ChordSegment(chord: nil, text: "One"),
            ChordSegment(chord: "D", text: " two"),
        ])
        #expect(pieces == [ChordSegment(chord: nil, text: "One "), ChordSegment(chord: "D", text: "two")])
    }

    // MARK: Sections, notes, language

    @Test func bracketedSectionLabelsAreHeadings() throws {
        let song = try ChordProParser.parse("{title: X}\n[Verse 1]\n[G]One\n[Pre-Chorus]\n[C]Two")
        #expect(song.lines == [
            .section("Verse 1"),
            .lyrics([ChordSegment(chord: "G", text: "One")]),
            .section("Pre-Chorus"),
            .lyrics([ChordSegment(chord: "C", text: "Two")]),
        ])
    }

    @Test func websitePreambleBecomesNotes() throws {
        let song = try ChordProParser.parse("""
        {title: X}
        CLICK TRANSPOSE FOR EASIER CHORDS
        Video lesson - https://example.com/v
        [Intro]
        [G] [C]
        [Verse]
        [G]Sparks are rising
        """)
        #expect(song.lines.prefix(2) == [
            .note("CLICK TRANSPOSE FOR EASIER CHORDS"),
            .note("Video lesson - https://example.com/v"),
        ])
        #expect(SongSummary(parsed: song).cueLine == "Sparks are rising")
    }

    @Test func plainFirstVerseIsNotANote() throws {
        // No section headings: chord-free lines stay lyrics.
        let song = try ChordProParser.parse("{title: X}\nNo chords here\n[G]Then chords")
        #expect(song.lines.first == .lyrics([ChordSegment(chord: nil, text: "No chords here")]))
    }

    @Test func linesWithChordsBeforeFirstHeadingStayLyrics() throws {
        let song = try ChordProParser.parse("{title: X}\nIntro words\n[G]Chord line\n[Chorus]\n[C]Two")
        #expect(song.lines.first == .lyrics([ChordSegment(chord: nil, text: "Intro words")]))
    }

    @Test func linkLinesAnywhereAreNotes() throws {
        let song = try ChordProParser.parse("{title: X}\n[G]One\nTutorial: www.example.com")
        #expect(song.lines.last == .note("Tutorial: www.example.com"))
    }

    @Test func strayHeadingInWebsitePreambleIsANote() throws {
        let song = try ChordProParser.parse("""
        {title: X}
        Capo: 1st fret
              E-A-D-G-B-e
        G     3-x-0-0-3(3)
        [Coda]
        Dsus4 x-x-0-2-3-3 or x-x-0-0-3-3
        ------------------------------
        [Intro]
        [G] [D]
        [Verse 1]
        [G]Sparks are rising
        """)
        #expect(song.lines.prefix(5) == [
            .note("Capo: 1st fret"),
            .note("E-A-D-G-B-e"),
            .note("G     3-x-0-0-3(3)"),
            .note("Coda"),
            .note("Dsus4 x-x-0-2-3-3 or x-x-0-0-3-3"),
        ])
        #expect(song.lines[5] == .section("Intro"))
        #expect(!song.lines.contains { if case .note(let text) = $0 { text.hasPrefix("---") } else { false } })
        #expect(SongSummary(parsed: song).cueLine == "Sparks are rising")
    }

    @Test func fingeringLinesLaterInTheSongAreNotes() throws {
        let song = try ChordProParser.parse("{title: X}\n[G]One\nC  x-3-2-0-1-0")
        #expect(song.lines.last == .note("C  x-3-2-0-1-0"))
    }

    @Test func barNotationBecomesChordRow() throws {
        let song = try ChordProParser.parse("{title: X}\n[G]One\n|(G) D/F# Em D | C D | G | % |")
        #expect(song.lines.last == .lyrics(["G", "D/F#", "Em", "D", "C", "D", "G"].map { ChordSegment(chord: $0, text: "") }))
    }

    @Test func shortDividersAndRepeatMarksAreTidied() throws {
        let song = try ChordProParser.parse("{title: X}\n[G]One\n----\nX\n(x2)")
        #expect(song.lines == [.lyrics([ChordSegment(chord: "G", text: "One")]), .note("X"), .note("(x2)")])
    }

    @Test func barLineWithWordsStaysText() {
        #expect(ChordProParser.barChords("The signs mean | D | % | repeat") == nil)
    }

    @Test func readsLanguage() throws {
        #expect(try ChordProParser.parse("{title: X}\n{language: Nepali}").language == "Nepali")
        #expect(try ChordProParser.parse("{title: X}\n{lang: Hindi}").language == "Hindi")
        #expect(try ChordProParser.parse("{title: X}").language == nil)
    }

    // MARK: Helpers

    private func parse(line: String) -> [ChordSegment] {
        var warnings: [ParseWarning] = []
        return ChordProParser.parseLyricLine(line, lineNumber: 1, warnings: &warnings)
    }
}
