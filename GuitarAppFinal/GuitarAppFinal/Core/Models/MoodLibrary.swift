//
//  MoodLibrary.swift
//  Moodchords
//

import Foundation
import SwiftData

/// Mood bookkeeping: seeding the defaults, matching songs to moods, and renaming.
enum MoodLibrary {

    enum RenameError: Error, Equatable {
        case emptyName
        /// Another mood already has this name (ignoring case).
        case duplicateName
    }

    /// How mood names are compared: trimmed and case-insensitive.
    /// (Only case is folded, not accents, so Devanagari vowel signs are never stripped.)
    nonisolated static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Inserts the 9 default moods if there are no moods yet (first launch).
    /// Defaults can't be deleted, so an empty table only happens on a fresh install.
    static func seedDefaultsIfNeeded(in context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Mood>()) == 0 else { return }
        for (index, swatch) in MoodSwatch.defaults.enumerated() {
            context.insert(Mood(
                name: swatch.name,
                symbol: swatch.symbol,
                hue: swatch.hue,
                subtitle: swatch.subtitle,
                sortOrder: index,
                isDefault: true
            ))
        }
        try context.save()
    }

    /// All moods in grid order.
    static func allMoods(in context: ModelContext) throws -> [Mood] {
        try context.fetch(FetchDescriptor<Mood>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    /// The songs tagged with a mood, optionally narrowed to a crowd.
    static func songs(for mood: Mood, in songs: [Song], crowd: CrowdFilter = .anyone) -> [Song] {
        songs.filter { $0.hasMood(named: mood.name) && $0.matches(crowd) }
    }

    /// Renames a mood and rewrites the matching tag on every song, so songs stay linked.
    static func rename(_ mood: Mood, to newName: String, in context: ModelContext) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw RenameError.emptyName }

        let others = try allMoods(in: context).filter { $0.id != mood.id }
        guard !others.contains(where: { $0.matches(name: trimmed) }) else {
            throw RenameError.duplicateName
        }

        let oldName = mood.name
        // SwiftData predicates can't compare array elements case-insensitively, so filter in memory.
        for song in try context.fetch(FetchDescriptor<Song>()) where song.hasMood(named: oldName) {
            song.moodNames = renamedTags(song.moodNames, from: oldName, to: trimmed)
        }
        mood.name = trimmed
        try context.save()
    }

    /// Adds a custom mood at the end of the grid.
    @discardableResult
    static func addMood(name: String, symbol: String, hue: Double, in context: ModelContext) throws -> Mood {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw RenameError.emptyName }
        let moods = try allMoods(in: context)
        guard !moods.contains(where: { $0.matches(name: trimmed) }) else { throw RenameError.duplicateName }
        let mood = Mood(name: trimmed, symbol: symbol, hue: hue, sortOrder: (moods.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(mood)
        try context.save()
        return mood
    }

    /// Changes a mood's name (updating its songs), icon and colour.
    static func update(_ mood: Mood, name: String, symbol: String, hue: Double, in context: ModelContext) throws {
        if name.trimmingCharacters(in: .whitespaces) != mood.name {
            try rename(mood, to: name, in: context)
        }
        mood.symbol = symbol
        mood.hue = hue
        try context.save()
    }

    enum DeleteError: Error, Equatable {
        /// The 9 default moods can be renamed and reordered, but not deleted.
        case isDefault
    }

    /// Deletes a custom mood. Songs keep their tags (so re-adding the mood brings them back).
    static func delete(_ mood: Mood, in context: ModelContext) throws {
        guard !mood.isDefault else { throw DeleteError.isDefault }
        context.delete(mood)
        try renumber(try allMoods(in: context).filter { $0.id != mood.id }, in: context)
    }

    /// Moves moods in grid order (from a List's `onMove`).
    static func move(from source: IndexSet, to destination: Int, in context: ModelContext) throws {
        try renumber(moved(try allMoods(in: context), from: source, to: destination), in: context)
    }

    /// Same rule as SwiftUI's `move(fromOffsets:toOffset:)`: `destination` is an index in the
    /// array before the move.
    nonisolated static func moved<T>(_ items: [T], from source: IndexSet, to destination: Int) -> [T] {
        let moving = source.map { items[$0] }
        var remaining = items.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.count(in: 0..<destination)
        remaining.insert(contentsOf: moving, at: min(max(insertAt, 0), remaining.count))
        return remaining
    }

    private static func renumber(_ moods: [Mood], in context: ModelContext) throws {
        for (index, mood) in moods.enumerated() where mood.sortOrder != index {
            mood.sortOrder = index
        }
        try context.save()
    }

    /// Replaces every tag matching `old` with `new`, keeping order and not adding duplicates.
    nonisolated static func renamedTags(_ tags: [String], from old: String, to new: String) -> [String] {
        var result: [String] = []
        for tag in tags {
            let replacement = normalized(tag) == normalized(old) ? new : tag
            if !result.contains(where: { normalized($0) == normalized(replacement) }) {
                result.append(replacement)
            }
        }
        return result
    }
}

extension Song {
    /// True if this song is tagged with the mood (ignoring case and surrounding spaces).
    func hasMood(named name: String) -> Bool {
        let target = MoodLibrary.normalized(name)
        return moodNames.contains { MoodLibrary.normalized($0) == target }
    }

    /// The song's crowd tags that are known crowds, in file order, without duplicates.
    var crowds: [Crowd] {
        var result: [Crowd] = []
        for crowd in crowdNames.compactMap(Crowd.init(name:)) where !result.contains(crowd) {
            result.append(crowd)
        }
        return result
    }
}
