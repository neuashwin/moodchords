//
//  Language.swift
//  Moodchords
//

import Foundation

/// The song languages the app filters by. Stored on songs as plain names
/// (from `{language: Nepali}` in the song text).
nonisolated enum SongLanguage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case english, nepali, hindi

    var id: Self { self }

    /// Reads "Nepali", "nepali", " Hindi " …; also the folder names used for importing.
    init?(name: String?) {
        guard let name else { return nil }
        self.init(rawValue: name.trimmingCharacters(in: .whitespaces).lowercased())
    }

    var title: String {
        switch self {
        case .english: "English"
        case .nepali: "Nepali"
        case .hindi: "Hindi"
        }
    }
}

/// The language filter on Home: all songs, or one language.
nonisolated enum LanguageFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all, english, nepali, hindi

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .english: "English"
        case .nepali: "Nepali"
        case .hindi: "Hindi"
        }
    }

    var language: SongLanguage? { SongLanguage(rawValue: rawValue) }
}

extension Song {
    var songLanguage: SongLanguage? { SongLanguage(name: language) }

    /// True if the song passes the language filter. Songs without a language only show under All.
    func matches(_ filter: LanguageFilter) -> Bool {
        guard let wanted = filter.language else { return true }
        return songLanguage == wanted
    }
}

extension Array where Element == Song {
    func filtered(by language: LanguageFilter) -> [Song] {
        language == .all ? self : filter { $0.matches(language) }
    }
}
