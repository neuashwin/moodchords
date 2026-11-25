//
//  ChordProParser.swift
//  Moodchords
//
//  Parses the Moodchords song format: a ChordPro subset with inline [chords].
//  See PRD §6.
//

import Foundation

/// A run of lyric text with the chord (if any) that sits above its first character.
nonisolated struct ChordSegment: Equatable, Hashable, Sendable {
    var chord: String?
    var text: String
}

nonisolated enum SongLine: Equatable, Hashable, Sendable {
    case lyrics([ChordSegment])
    case section(String)
    case blank
    /// Not part of the song: notes copied from a chord website ("Video lesson – https://…"),
    /// shown small and muted instead of as lyrics.
    case note(String)
}

nonisolated struct ParseWarning: Equatable, Sendable, CustomStringConvertible {
    var line: Int
    var message: String
    var description: String { "Line \(line): \(message)" }
}

nonisolated enum ParseError: Error, Equatable, LocalizedError {
    case empty
    case missingTitle

    var errorDescription: String? {
        switch self {
        case .empty: "The song is empty."
        case .missingTitle: "The song needs a title. Add a line like {title: My Song}."
        }
    }
}

nonisolated struct ParsedSong: Equatable, Sendable {
    /// Used when a song has no {duration:} (PRD §5.3).
    static let defaultDuration = 210

    var title: String
    var artist: String?
    var key: String?
    /// Seconds, or nil if the file didn't specify one.
    var duration: Int?
    var moods: [String]
    var crowds: [String] = []
    /// Capo fret, or nil for no capo.
    var capo: Int? = nil
    /// From `{language: Nepali}`, as written.
    var language: String? = nil
    var lines: [SongLine]
    var warnings: [ParseWarning]

    var effectiveDuration: Int { duration ?? Self.defaultDuration }

    /// Unique chords in order of first appearance.
    var chords: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for case .lyrics(let segments) in lines {
            for chord in segments.compactMap(\.chord) where seen.insert(chord).inserted {
                result.append(chord)
            }
        }
        return result
    }
}

nonisolated enum ChordProParser {

    static func parse(_ source: String) throws -> ParsedSong {
        var text = source
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ParseError.empty
        }

        var title: String?
        var artist: String?
        var key: String?
        var duration: Int?
        var moods: [String] = []
        var crowds: [String] = []
        var capo: Int?
        var language: String?
        var lines: [SongLine] = []
        var warnings: [ParseWarning] = []

        let rawLines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        for (index, raw) in rawLines.enumerated() {
            let lineNumber = index + 1
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                lines.append(.blank)
                continue
            }
            if line.hasPrefix("#") { continue } // ChordPro comment

            // Chord sites sometimes wrap lyrics in braces ("{Pyaar ka ...,"). Only treat a
            // line as a directive when it starts like one: {name} or {name: value}.
            if line.hasPrefix("{"), looksLikeDirective(line) {
                guard line.hasSuffix("}") else {
                    warnings.append(.init(line: lineNumber, message: "Directive is missing a closing }, so it was skipped."))
                    continue
                }
                let inner = line.dropFirst().dropLast()
                let name: String
                let value: String
                if let colon = inner.firstIndex(of: ":") {
                    name = inner[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                    value = inner[inner.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                } else {
                    name = inner.trimmingCharacters(in: .whitespaces).lowercased()
                    value = ""
                }

                switch name {
                case "title", "t":
                    title = value.isEmpty ? nil : value
                case "artist", "subtitle", "st":
                    artist = value.isEmpty ? nil : value
                case "key":
                    key = value.isEmpty ? nil : value
                case "duration":
                    if let seconds = parseDuration(value) {
                        duration = seconds
                    } else {
                        warnings.append(.init(line: lineNumber, message: "Couldn't read duration \"\(value)\". Use minutes:seconds, e.g. {duration: 4:30}."))
                    }
                case "mood", "moods":
                    appendTags(value, to: &moods)
                case "crowd", "crowds":
                    appendTags(value, to: &crowds)
                case "capo":
                    if let fret = parseCapo(value) {
                        capo = fret > 0 ? fret : nil
                    } else {
                        warnings.append(.init(line: lineNumber, message: "Couldn't read capo \"\(value)\". Use a fret number, e.g. {capo: 2}."))
                    }
                case "language", "lang":
                    language = value.isEmpty ? nil : value
                case "comment", "c", "comment_italic", "ci":
                    if !value.isEmpty { lines.append(.section(value)) }
                case "start_of_solo", "sos":
                    lines.append(.section(value.isEmpty ? "Solo" : value))
                case "end_of_solo", "eos":
                    break
                case "start_of_chorus", "soc":
                    lines.append(.section(value.isEmpty ? "Chorus" : value))
                case "start_of_verse", "sov":
                    lines.append(.section(value.isEmpty ? "Verse" : value))
                case "start_of_bridge", "sob":
                    lines.append(.section(value.isEmpty ? "Bridge" : value))
                case "end_of_chorus", "eoc", "end_of_verse", "eov", "end_of_bridge", "eob":
                    break
                default:
                    warnings.append(.init(line: lineNumber, message: "Unknown directive {\(name)} was ignored."))
                }
                continue
            }

            // A line that is only "[Verse 1]" or "[Intro]" is a section heading, not a chord.
            if let label = ChordSheetConverter.sectionLabel(line) {
                lines.append(.section(label))
                continue
            }

            lines.append(.lyrics(parseLyricLine(line, lineNumber: lineNumber, warnings: &warnings)))
        }

        guard let title else { throw ParseError.missingTitle }
        lines = markNotes(in: lines)
        if duration == nil {
            warnings.append(.init(line: 1, message: "No {duration:} found. Auto-scroll will assume 3:30."))
        }

        return ParsedSong(
            title: title,
            artist: artist,
            key: key,
            duration: duration,
            moods: moods,
            crowds: crowds,
            capo: capo,
            language: language,
            lines: tidyBlankLines(lines),
            warnings: warnings
        )
    }

    /// Turns chord-website clutter into notes:
    /// - everything chord-free before the song starts (instructions, "Capo: 1st fret", legends,
    ///   stray headings). The song starts at the last heading before the first chord, so this
    ///   only applies to songs with headings, and a plain first verse is never mistaken for a note;
    /// - chord-fingering tables ("G  3-x-0-0-3", "E-A-D-G-B-e") and lines with web links, anywhere.
    /// Divider lines ("------") are dropped.
    static func markNotes(in lines: [SongLine]) -> [SongLine] {
        let firstChord = lines.firstIndex { line in
            if case .lyrics(let segments) = line { segments.contains { $0.chord != nil } } else { false }
        }
        let songStart: Int? = firstChord.flatMap { chordIndex in
            lines[..<chordIndex].lastIndex { if case .section = $0 { true } else { false } }
        }

        return lines.enumerated().compactMap { index, line in
            let inPreamble = songStart.map { index < $0 } ?? false
            switch line {
            case .section(let name) where inPreamble:
                return .note(name)
            case .lyrics(let segments) where segments.allSatisfy({ $0.chord == nil }):
                let text = segments.map(\.text).joined().trimmingCharacters(in: .whitespaces)
                if isDivider(text) { return nil }
                // "| G D/F# | Em (C) |": bar notation is really a row of chords.
                if let chords = barChords(text) {
                    return .lyrics(chords.map { ChordSegment(chord: $0, text: "") })
                }
                if inPreamble || isLink(text) || isFingering(text) || isRepeatMark(text) { return .note(text) }
                return line
            default:
                return line
            }
        }
    }

    private static func isLink(_ text: String) -> Bool {
        text.range(of: #"https?://|www\."#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// "G  3-x-0-0-3(3)", "Dsus4 x-x-0-2-3-3 or …", "E-A-D-G-B-e", "320003".
    private static func isFingering(_ text: String) -> Bool {
        text.range(of: #"(^|\s)[0-9xX]([-–][0-9xX(][0-9)]?){4,}"#, options: .regularExpression) != nil
            || text.range(of: #"^[EADGBe]-[EADGBe]-[EADGBe]-[EADGBe]-[EADGBe]-[EADGBe]$"#, options: .regularExpression) != nil
    }

    /// A line of only dashes, equals signs, underscores or similar ("----", "= = =").
    private static func isDivider(_ text: String) -> Bool {
        let marks = text.filter { !$0.isWhitespace }
        return marks.count >= 3 && marks.allSatisfy { "-=_*~–—".contains($0) }
    }

    /// "X", "x2", "(x3)", "2x": a repeat mark on its own line.
    private static func isRepeatMark(_ text: String) -> Bool {
        text.range(of: #"^\(?(?:[xX×]\d*|\d+[xX×])\)?$"#, options: .regularExpression) != nil
    }

    /// The chords of a bar-notation line ("|(G) D/F# Em D | C D | G | % |"), or nil if the
    /// line isn't one: it needs a bar line and nothing but chords, bars, "%" and parentheses.
    static func barChords(_ text: String) -> [String]? {
        guard text.contains("|") else { return nil }
        var chords: [String] = []
        for token in text.split(whereSeparator: \.isWhitespace) {
            let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: "|()[]"))
            if cleaned.isEmpty || cleaned == "%" || cleaned.lowercased().range(of: #"^x?\d+x?$"#, options: .regularExpression) != nil {
                continue
            }
            guard ChordSheetConverter.isChord(cleaned) else { return nil }
            chords.append(cleaned)
        }
        return chords.isEmpty ? nil : chords
    }

    // MARK: - Lyric lines

    /// Splits `[G]Timi [C]bina` into chord segments.
    ///
    /// Works on Unicode scalars, not Characters: in Devanagari a `]` followed by a
    /// vowel sign (e.g. `]ि`) forms a single Swift Character, so a Character-level
    /// search for `]` would miss the bracket.
    static func parseLyricLine(_ line: String, lineNumber: Int, warnings: inout [ParseWarning]) -> [ChordSegment] {
        let scalars = Array(line.unicodeScalars)
        var segments: [ChordSegment] = []
        var currentChord: String?
        var text = String.UnicodeScalarView()

        func flush() {
            if currentChord != nil || !text.isEmpty {
                segments.append(ChordSegment(chord: currentChord, text: String(text)))
            }
            text = String.UnicodeScalarView()
        }

        var i = 0
        while i < scalars.count {
            let scalar = scalars[i]
            if scalar == "[" {
                if let close = scalars[(i + 1)...].firstIndex(of: "]") {
                    flush()
                    let chord = String(String.UnicodeScalarView(scalars[(i + 1)..<close]))
                        .trimmingCharacters(in: .whitespaces)
                    currentChord = chord.isEmpty ? nil : chord
                    i = close + 1
                    continue
                }
                warnings.append(.init(line: lineNumber, message: "A [ has no matching ], so it's shown as lyrics."))
            }
            text.append(scalar)
            i += 1
        }
        flush()

        return repairSplitLetters(segments, lineNumber: lineNumber, warnings: &warnings)
    }

    /// If a chord was placed in the middle of a letter (before a vowel sign or
    /// other combining mark), move those marks back onto the previous segment so
    /// the letter isn't broken. The chord then sits on the next whole letter.
    private static func repairSplitLetters(_ segments: [ChordSegment], lineNumber: Int, warnings: inout [ParseWarning]) -> [ChordSegment] {
        var result = segments
        var index = 1
        while index < result.count {
            let scalars = Array(result[index].text.unicodeScalars)
            let markCount = scalars.prefix(while: isCombining).count
            if markCount > 0 {
                result[index - 1].text.unicodeScalars.append(contentsOf: scalars[..<markCount])
                result[index].text = String(String.UnicodeScalarView(scalars[markCount...]))
                if let chord = result[index].chord {
                    warnings.append(.init(line: lineNumber, message: "Chord [\(chord)] was inside a letter, so it was moved to the next letter."))
                }
            }
            index += 1
        }
        return result
    }

    private static func isCombining(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: scalar == "\u{200D}" || scalar == "\u{200C}" // ZWJ / ZWNJ
        }
    }

    // MARK: - Helpers

    /// `{title: X}`, `{soc}`, `{duration: 4:30` → true. `{Pyaar ka, ...` → false.
    static func looksLikeDirective(_ line: String) -> Bool {
        line.range(of: #"^\{\s*[A-Za-z_]+\s*(:|\}|$)"#, options: .regularExpression) != nil
    }

    /// Splits "Romantic, Campfire" into tags, skipping blanks and case-insensitive duplicates.
    private static func appendTags(_ value: String, to tags: inout [String]) {
        for tag in value.split(separator: ",") {
            let trimmed = tag.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
            else { continue }
            tags.append(trimmed)
        }
    }

    /// Accepts `2`, `2nd fret`, `none` / `no capo` (→ 0).
    static func parseCapo(_ value: String) -> Int? {
        let lower = value.lowercased().trimmingCharacters(in: .whitespaces)
        if lower == "none" || lower == "no capo" || lower == "no" { return 0 }
        guard let match = lower.range(of: #"^\d+"#, options: .regularExpression),
              let fret = Int(lower[match]), fret <= 12 else { return nil }
        return fret
    }

    /// Accepts `4:30`, `1:02:03`, or plain seconds `270`.
    static func parseDuration(_ value: String) -> Int? {
        let parts = value.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count, numbers.allSatisfy({ $0 >= 0 }) else { return nil }
        if parts.count > 1, numbers.dropFirst().contains(where: { $0 >= 60 }) { return nil }
        let seconds = numbers.reduce(0) { $0 * 60 + $1 }
        return seconds > 0 ? seconds : nil
    }

    /// Drops leading/trailing blank lines and collapses runs of blanks into one.
    private static func tidyBlankLines(_ lines: [SongLine]) -> [SongLine] {
        var result: [SongLine] = []
        for line in lines {
            if line == .blank, result.isEmpty || result.last == .blank { continue }
            result.append(line)
        }
        while result.last == .blank { result.removeLast() }
        return result
    }
}

// MARK: - Layout pieces

nonisolated enum ChordSheetLayout {
    /// Splits segments into word-sized pieces so a line can wrap between words.
    /// The chord stays on the first piece of its segment.
    ///
    /// Runs of spaces collapse to one. Sheets converted from "chords above lyrics" pad
    /// lines with spaces to reach a chord's column, and each space would otherwise become
    /// its own piece and open a gap in the line.
    static func pieces(from segments: [ChordSegment]) -> [ChordSegment] {
        var result: [ChordSegment] = []
        for segment in segments {
            var words: [String] = []
            var current = ""
            for character in collapsingSpaces(segment.text) {
                current.append(character)
                if character.isWhitespace {
                    words.append(current)
                    current = ""
                }
            }
            if !current.isEmpty { words.append(current) }

            // A leading space belongs to the previous word, not to this chord's piece.
            if words.first == " " {
                words.removeFirst()
                if let last = result.indices.last, !result[last].text.hasSuffix(" ") {
                    result[last].text += " "
                }
            }
            if words.isEmpty {
                // Chord over nothing (end of line, or between words): keep it as a chord-only piece.
                if segment.chord != nil { result.append(ChordSegment(chord: segment.chord, text: "")) }
                continue
            }
            for (i, word) in words.enumerated() {
                result.append(ChordSegment(chord: i == 0 ? segment.chord : nil, text: word))
            }
        }
        return result
    }

    private static func collapsingSpaces(_ text: String) -> String {
        var output = ""
        var lastWasSpace = false
        for character in text {
            if character.isWhitespace {
                if !lastWasSpace { output.append(" ") }
                lastWasSpace = true
            } else {
                output.append(character)
                lastWasSpace = false
            }
        }
        return output
    }
}
