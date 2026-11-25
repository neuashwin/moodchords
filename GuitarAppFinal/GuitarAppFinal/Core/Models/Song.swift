//
//  Song.swift
//  Moodchords
//

import Foundation
import SwiftData

@Model
final class Song {
    var title: String
    var artist: String?
    var key: String?
    /// Seconds the auto-scroll takes from top to bottom.
    var durationSeconds: Int
    /// Mood names from the file. M2 turns these into editable Mood records.
    var moodNames: [String]
    var crowdNames: [String] = []
    /// The original song text. Parsed on display so the format stays the source of truth.
    var source: String
    var isFavorite: Bool
    /// "Ready to play": the owner knows this song well enough to perform it.
    var isReady: Bool = false
    var createdAt: Date
    /// From `{language:}` in the text ("English", "Nepali", "Hindi"…), for the language filter.
    var language: String? = nil
    /// Play-mode speed nudge saved for this song (1 = scroll over exactly the song's length).
    var scrollSpeed: Double = 1.0

    init(parsed: ParsedSong, source: String) {
        self.title = parsed.title
        self.artist = parsed.artist
        self.key = parsed.key
        self.durationSeconds = parsed.effectiveDuration
        self.moodNames = parsed.moods
        self.crowdNames = parsed.crowds
        self.language = parsed.language
        self.source = source
        self.isFavorite = false
        self.createdAt = .now
    }

    /// Replaces the song's text after editing and refreshes everything read from it.
    /// Favourite, ready-to-play and speed are kept.
    func update(parsed: ParsedSong, source: String) {
        title = parsed.title
        artist = parsed.artist
        key = parsed.key
        durationSeconds = parsed.effectiveDuration
        moodNames = parsed.moods
        crowdNames = parsed.crowds
        language = parsed.language
        self.source = source
    }

    var formattedDuration: String {
        String(format: "%d:%02d", durationSeconds / 60, durationSeconds % 60)
    }
}
