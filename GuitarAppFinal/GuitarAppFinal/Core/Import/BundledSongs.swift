//
//  BundledSongs.swift
//  Moodchords
//
//  The owner's personal song files, built into Debug builds so they're in the library
//  without importing. Personal use only: Release builds never load them, and the
//  `BundledSongs` folder must be deleted before any App Store release (see CLAUDE.md).
//

#if DEBUG
import Foundation
import SwiftData

enum BundledSongs {
    /// Names of bundled files already loaded once, so a song you delete doesn't come back.
    private static let loadedKey = "bundledSongsLoaded"

    /// The bundled song files (copied into the app as `BundledSong-<Language>-<Title>.txt`).
    static func files(in bundle: Bundle = .main) -> [URL] {
        (bundle.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("BundledSong-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Adds any bundled song not loaded before. Songs already in the library are skipped
    /// (and get their language filled in if they were missing it).
    @discardableResult
    static func loadNew(into context: ModelContext, defaults: UserDefaults = .standard,
                        bundle: Bundle = .main) -> ImportReport? {
        var loaded = Set(defaults.stringArray(forKey: loadedKey) ?? [])
        let new = files(in: bundle).filter { !loaded.contains($0.lastPathComponent) }
        guard !new.isEmpty else { return nil }

        let moods = (try? MoodLibrary.allMoods(in: context).map(\.name)) ?? []
        let report = SongImporter.importFiles(new, into: context, knownMoods: moods)
        loaded.formUnion(new.map(\.lastPathComponent))
        defaults.set(Array(loaded).sorted(), forKey: loadedKey)
        return report
    }
}
#endif
