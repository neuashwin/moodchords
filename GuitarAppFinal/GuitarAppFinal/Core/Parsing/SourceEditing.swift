//
//  SourceEditing.swift
//  Moodchords
//

import Foundation

/// Reads and rewrites single `{name: value}` directive lines in a song's source text, so the
/// edit screen's fields (title, key, moods…) can change the text, which stays the source of truth.
nonisolated enum SourceEditing {

    /// The header directives the edit screen offers, with the short names the parser also accepts.
    enum Field: String, CaseIterable {
        case title, artist, key, capo, duration, mood, crowd, language

        var aliases: Set<String> {
            switch self {
            case .language: ["language", "lang"]
            case .title: ["title", "t"]
            case .artist: ["artist", "subtitle", "st"]
            case .key: ["key"]
            case .capo: ["capo"]
            case .duration: ["duration"]
            case .mood: ["mood", "moods"]
            case .crowd: ["crowd", "crowds"]
            }
        }
    }

    /// The value of the first matching directive, trimmed; nil if there isn't one.
    static func value(of field: Field, in source: String) -> String? {
        for line in source.components(separatedBy: "\n") {
            if let (name, value) = directive(in: line), field.aliases.contains(name) {
                return value
            }
        }
        return nil
    }

    /// Comma-separated values (moods, crowds), trimmed, empties dropped.
    static func list(of field: Field, in source: String) -> [String] {
        (value(of: field, in: source) ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Sets a directive. Replaces the first matching line (removing any duplicates), or adds a
    /// new line after the header directives. An empty value removes the directive.
    static func setting(_ field: Field, to newValue: String?, in source: String) -> String {
        var lines = source.components(separatedBy: "\n")
        let matches = lines.indices.filter { index in
            directive(in: lines[index]).map { field.aliases.contains($0.name) } ?? false
        }
        let trimmed = newValue?.trimmingCharacters(in: .whitespaces) ?? ""
        let newLine = "{\(field.rawValue): \(trimmed)}"

        if trimmed.isEmpty {
            for index in matches.reversed() { lines.remove(at: index) }
        } else if let first = matches.first {
            for index in matches.dropFirst().reversed() { lines.remove(at: index) }
            lines[first] = newLine
        } else {
            lines.insert(newLine, at: insertionIndex(in: lines))
        }
        return lines.joined(separator: "\n")
    }

    /// Sets a comma-separated list directive.
    static func setting(_ field: Field, toList values: [String], in source: String) -> String {
        setting(field, to: values.joined(separator: ", "), in: source)
    }

    // MARK: Helpers

    /// (lowercased name, trimmed value) if the line is a directive.
    private static func directive(in line: String) -> (name: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard ChordProParser.looksLikeDirective(trimmed), trimmed.hasSuffix("}") else { return nil }
        let inner = trimmed.dropFirst().dropLast()
        if let colon = inner.firstIndex(of: ":") {
            let name = inner[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = inner[inner.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return (name, value)
        }
        return (inner.trimmingCharacters(in: .whitespaces).lowercased(), "")
    }

    /// Just after the last header directive in the opening block of the file (title first).
    private static func insertionIndex(in lines: [String]) -> Int {
        let headerNames = Field.allCases.reduce(into: Set<String>()) { $0.formUnion($1.aliases) }
        var index = 0
        for (offset, line) in lines.enumerated() {
            if let (name, _) = directive(in: line), headerNames.contains(name) {
                index = offset + 1
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
        }
        return index
    }
}
