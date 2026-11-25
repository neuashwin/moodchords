//
//  Mood.swift
//  Moodchords
//

import Foundation
import SwiftData

/// A mood on the home grid (Romantic, Campfire…). The 9 defaults are seeded on first launch;
/// the owner can add custom ones.
///
/// Songs link to moods by name (`Song.moodNames`, matched case-insensitively), so the song
/// files stay the source of truth. Renaming a mood must go through `MoodLibrary.rename`,
/// which updates the songs too.
@Model
final class Mood {
    @Attribute(.unique) var id: UUID
    var name: String
    /// SF Symbol name.
    var symbol: String
    /// OKLCH hue (0–360); the tile colour is `oklch(0.80 0.11 hue)`.
    var hue: Double
    /// Optional second line, e.g. "Dashain · Tihar" for Festival.
    var subtitle: String?
    /// Position on the home grid (0 first).
    var sortOrder: Int
    /// Defaults can be renamed and reordered but not deleted.
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        hue: Double,
        subtitle: String? = nil,
        sortOrder: Int,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.hue = hue
        self.subtitle = subtitle
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }

    /// What tiles and chips need to draw this mood.
    var swatch: MoodSwatch {
        MoodSwatch(name: name, symbol: symbol, hue: hue, subtitle: subtitle)
    }

    /// True if a song's mood tag refers to this mood (ignoring case and surrounding spaces).
    func matches(name tag: String) -> Bool {
        MoodLibrary.normalized(tag) == MoodLibrary.normalized(name)
    }
}
