//
//  SongSummary.swift
//  Moodchords
//

import Foundation

/// What a song row shows at a glance: key, capo, length and how the song starts.
/// Worked out from the song's source text, which stays the source of truth.
nonisolated struct SongSummary: Equatable {
    var key: String?
    var capo: Int?
    /// Seconds, or nil if the file doesn't say.
    var duration: Int?
    /// The first lyric line, without chords.
    var firstLine: String?
    /// The first few chords, for songs without lyrics.
    var openingChords: [String]

    init(parsed: ParsedSong) {
        key = parsed.key
        capo = parsed.capo
        duration = parsed.duration
        openingChords = Array(parsed.chords.prefix(4))
        firstLine = parsed.lines.lazy.compactMap { line -> String? in
            guard case .lyrics(let segments) = line else { return nil }
            let text = segments.map(\.text).joined()
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return text.isEmpty ? nil : text
        }.first
    }

    /// Parses `source`; a song that no longer parses gets an empty summary.
    init(source: String) {
        if let parsed = try? ChordProParser.parse(source) {
            self.init(parsed: parsed)
        } else {
            self.init(parsed: ParsedSong(title: "", moods: [], lines: [], warnings: []))
        }
    }

    /// The mono spec line: "G · CAPO 2 · 2:45". An unknown key shows "KEY ?", and a missing
    /// length shows the assumed default with a "~" so it's clearly a guess.
    var metaLine: String {
        var parts = [key ?? "KEY ?"]
        if let capo { parts.append("CAPO \(capo)") }
        if let duration {
            parts.append(Self.formatDuration(duration))
        } else {
            parts.append("~" + Self.formatDuration(ParsedSong.defaultDuration))
        }
        return parts.joined(separator: " · ")
    }

    /// The italic cue under the title: the first lyric line, else the opening chords.
    var cueLine: String {
        if let firstLine { return firstLine }
        if !openingChords.isEmpty { return "Starts on " + openingChords.joined(separator: " · ") }
        return "No cue yet. Add how it starts."
    }

    /// "4:05" style.
    static func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

extension Song {
    var summary: SongSummary { SongSummary(source: source) }
}
