//
//  ChordSheetConverter.swift
//  Moodchords
//
//  Converts the common "chords on the line above the lyrics" layout used by most
//  chord websites into Moodchords' inline-[chord] format, so a pasted or imported
//  sheet works without hand-editing.
//

import Foundation

nonisolated enum ChordSheetConverter {

    /// Returns `text` converted to inline chords if it looks like a chords-above
    /// sheet; otherwise returns it unchanged.
    static func convertIfNeeded(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        guard needsConversion(lines) else { return text }
        return convert(lines).joined(separator: "\n")
    }

    // MARK: - Detection

    static func needsConversion(_ lines: [String]) -> Bool {
        let body = lines.filter { !isDirective($0) }
        let hasInlineChords = body.contains { line in
            line.contains("[") && !isChordLine(line) && !isSectionLabel(line)
                && inlineChordPattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
        }
        let chordLineCount = body.filter(isChordLine).count
        return !hasInlineChords && chordLineCount > 0
    }

    // MARK: - Conversion

    static func convert(_ lines: [String]) -> [String] {
        var output: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]

            if isDirective(line) {
                output.append(line)
            } else if isFingeringLine(line) || isTabLine(line) {
                // Chord diagrams are drawn by the app; tab lines can't be shown inline.
            } else if let label = sectionLabel(line) {
                output.append("{comment: \(label)}")
            } else if isChordLine(line) {
                let next = index + 1 < lines.count ? lines[index + 1] : nil
                if let next, isLyricLine(next) {
                    output.append(merge(chordLine: line, lyricLine: next))
                    index += 1
                } else {
                    output.append(chordOnlyLine(line))
                }
            } else {
                output.append(line)
            }
            index += 1
        }
        return output
    }

    /// Places each chord into the lyric line at the column it sat above.
    static func merge(chordLine: String, lyricLine: String) -> String {
        var lyric = Array(lyricLine)
        let chords = chordPositions(in: chordLine)
        if let lastColumn = chords.last?.column, lastColumn > lyric.count {
            lyric.append(contentsOf: Array(repeating: " ", count: lastColumn - lyric.count))
        }
        for (column, chord) in chords.reversed() {
            lyric.insert(contentsOf: "[\(chord)]", at: min(column, lyric.count))
        }
        return String(lyric)
    }

    static func chordOnlyLine(_ line: String) -> String {
        chordPositions(in: line).map { "[\($0.chord)]" }.joined(separator: " ")
    }

    /// Chord tokens with their character column. Non-chord tokens (like `|` or `x2`) are dropped.
    static func chordPositions(in line: String) -> [(column: Int, chord: String)] {
        var result: [(Int, String)] = []
        var token = ""
        var start = 0
        for (offset, character) in (Array(line) + [" "]).enumerated() {
            if character.isWhitespace {
                if !token.isEmpty, isChord(token) { result.append((start, token)) }
                token = ""
            } else {
                if token.isEmpty { start = offset }
                token.append(character)
            }
        }
        return result
    }

    // MARK: - Line classification

    private static let chordPattern = try! NSRegularExpression(
        pattern: #"^[A-G](?:#|b)?(?:maj|min|m|M|dim|aug|sus|add|\+|°|ø|[0-9]|#|b|\(|\))*(?:/[A-G](?:#|b)?)?$"#
    )
    private static let inlineChordPattern = try! NSRegularExpression(
        pattern: #"\[[A-G](?:#|b)?[^\]\s]*\]"#
    )
    /// Tokens allowed on a chord line besides chords: bar lines, repeats, "N.C." and similar.
    private static let fillerTokens: Set<String> = ["|", "||", "/", "-", "–", "N.C.", "NC", "(", ")"]

    static func isChord(_ token: String) -> Bool {
        chordPattern.firstMatch(in: token, range: NSRange(token.startIndex..., in: token)) != nil
    }

    static func isChordLine(_ line: String) -> Bool {
        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return false }
        var chordCount = 0
        for token in tokens {
            if isChord(token) { chordCount += 1; continue }
            if fillerTokens.contains(token) || isRepeatMarker(token) { continue }
            return false
        }
        return chordCount > 0
    }

    static func isLyricLine(_ line: String) -> Bool {
        !line.trimmingCharacters(in: .whitespaces).isEmpty
            && !isChordLine(line) && !isDirective(line) && sectionLabel(line) == nil
            && !isFingeringLine(line) && !isTabLine(line)
    }

    private static func isRepeatMarker(_ token: String) -> Bool {
        let lower = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        return lower.range(of: #"^x?\d+x?$"#, options: .regularExpression) != nil
    }

    private static func isDirective(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
    }

    static func isSectionLabel(_ line: String) -> Bool { sectionLabel(line) != nil }

    /// `[Verse 1]` → "Verse 1". A bracketed chord like `[G]` is not a label.
    static func sectionLabel(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count > 2 else { return nil }
        let inner = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        guard !inner.contains("["), !isChord(inner) else { return nil }
        return inner
    }

    /// A chord-diagram table row such as `Em7   0-2-2-0-3-3` or `G 320003`.
    private static func isFingeringLine(_ line: String) -> Bool {
        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count == 2, isChord(tokens[0]) else { return false }
        return tokens[1].range(of: #"^[0-9xX]([-\s]?[0-9xX]){5}$"#, options: .regularExpression) != nil
    }

    /// Guitar tab staff lines like `e|---0---|`.
    private static func isTabLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces)
            .range(of: #"^[eBGDAEbgda]\s?\|[-0-9hpbr/\\|~x\s]*$"#, options: .regularExpression) != nil
    }
}
