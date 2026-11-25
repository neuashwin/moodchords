//
//  SongImporter.swift
//  Moodchords
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

struct ImportResult {
    let song: Song
    let warnings: [ParseWarning]
}

/// What happened in a multi-file or folder import (design 7C).
struct ImportReport: Identifiable {
    struct Check: Identifiable, Equatable {
        enum Kind: Equatable {
            /// No or unreadable length.
            case length
            case key
            case mood
            /// Not a song file, or already imported.
            case skipped
            /// Couldn't be read or parsed, or another parser warning.
            case problem
        }

        let id = UUID()
        var title: String
        var kind: Kind
        var message: String

        static func == (lhs: Check, rhs: Check) -> Bool {
            lhs.title == rhs.title && lhs.kind == rhs.kind && lhs.message == rhs.message
        }
    }

    let id = UUID()
    var addedTitles: [String] = []
    /// Songs already in the library that got their language from the folder name.
    var languageUpdates = 0
    /// Song files looked at (whether or not they were added).
    var fileCount = 0
    /// Set when a folder was picked.
    var folderName: String?
    var checks: [Check] = []
}

enum SongImportError: LocalizedError {
    case unreadable(String)
    case invalid(String, ParseError)

    var errorDescription: String? {
        switch self {
        case .unreadable(let name): "\(name): couldn't read the file as text."
        case .invalid(let name, let error): "\(name): \(error.localizedDescription)"
        }
    }
}

enum SongImporter {
    static let allowedTypes: [UTType] = [
        .plainText,
        .text,
        // Undeclared extensions get a dynamic type conforming to public.data, so we must
        // ask for that same type. Conforming to .plainText here would grey the files out.
        UTType(filenameExtension: "cho"),
        UTType(filenameExtension: "chordpro"),
    ].compactMap { $0 }

    static func importFile(at url: URL, into context: ModelContext) throws -> ImportResult {
        let name = url.lastPathComponent
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw SongImportError.unreadable(name) }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw SongImportError.unreadable(name)
        }
        do {
            return try importText(text, into: context)
        } catch let error as ParseError {
            throw SongImportError.invalid(name, error)
        }
    }

    static func importText(_ text: String, into context: ModelContext) throws -> ImportResult {
        // Sheets copied from chord sites put chords on the line above; store them inline.
        let source = ChordSheetConverter.convertIfNeeded(text)
        let parsed = try ChordProParser.parse(source)
        let song = Song(parsed: parsed, source: source)
        context.insert(song)
        return ImportResult(song: song, warnings: parsed.warnings)
    }

    // MARK: Several files or a folder

    /// File extensions treated as song files when importing a folder.
    static let songExtensions: Set<String> = ["txt", "text", "cho", "chordpro", "chopro", "crd", "pro"]

    /// Imports the picked files and/or folders (folders are searched, including subfolders).
    /// Files already in the library (same text) are skipped, and anything worth a look is
    /// reported as a check rather than failing the whole import.
    static func importFiles(_ urls: [URL], into context: ModelContext, knownMoods: [String]) -> ImportReport {
        var report = ImportReport()
        // Existing songs by their text (ignoring any {language:} line, which import may add).
        var existing: [String: Song] = [:]
        for song in (try? context.fetch(FetchDescriptor<Song>())) ?? [] {
            existing[duplicateKey(song.source)] = song
        }
        let moodKeys = Set(knownMoods.map(MoodLibrary.normalized))

        func process(_ file: URL, fromFolder: Bool) {
            let name = file.lastPathComponent
            guard songExtensions.contains(file.pathExtension.lowercased()) else {
                if fromFolder { report.checks.append(.init(title: name, kind: .skipped, message: "Skipped. It isn't a song file.")) }
                return
            }
            report.fileCount += 1
            guard let data = try? Data(contentsOf: file),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16)
            else {
                report.checks.append(.init(title: name, kind: .problem, message: "Couldn't read the file as text."))
                return
            }
            var source = ChordSheetConverter.convertIfNeeded(text)
            // A song inside a folder called English, Nepali or Hindi gets that language.
            let folderLanguage = fromFolder ? SongLanguage(name: file.deletingLastPathComponent().lastPathComponent) : nil
            if let folderLanguage, SourceEditing.value(of: .language, in: source) == nil {
                source = SourceEditing.setting(.language, to: folderLanguage.title, in: source)
            }

            if let duplicate = existing[duplicateKey(source)] {
                // Already imported: just fill in a missing language (from the folder or the file).
                let incoming = folderLanguage ?? SongLanguage(name: SourceEditing.value(of: .language, in: source))
                if let incoming, duplicate.language == nil {
                    let updated = SourceEditing.setting(.language, to: incoming.title, in: duplicate.source)
                    if let parsed = try? ChordProParser.parse(updated) {
                        duplicate.update(parsed: parsed, source: updated)
                        report.languageUpdates += 1
                        return
                    }
                }
                report.checks.append(.init(title: name, kind: .skipped, message: "Already in your library, so it was skipped."))
                return
            }
            do {
                let parsed = try ChordProParser.parse(source)
                let song = Song(parsed: parsed, source: source)
                context.insert(song)
                existing[duplicateKey(source)] = song
                report.addedTitles.append(song.title)
                report.checks += checks(for: parsed, moodKeys: moodKeys)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "Couldn't read this song."
                report.checks.append(.init(title: name, kind: .problem, message: message))
            }
        }

        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                report.folderName = url.lastPathComponent
                let files = FileManager.default.enumerator(
                    at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
                )
                // Sort so songs are added in a predictable (alphabetical) order.
                let regularFiles = (files?.allObjects as? [URL] ?? [])
                    .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
                    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                for file in regularFiles { process(file, fromFolder: true) }
            } else {
                process(url, fromFolder: false)
            }
        }
        try? context.save()
        return report
    }

    /// Friendly notes about an imported song: parser warnings, no key, no or unknown moods.
    static func checks(for parsed: ParsedSong, moodKeys: Set<String>) -> [ImportReport.Check] {
        var checks: [ImportReport.Check] = []
        for warning in parsed.warnings {
            let kind: ImportReport.Check.Kind = warning.message.contains("duration") ? .length : .problem
            checks.append(.init(title: parsed.title, kind: kind, message: warning.message))
        }
        if parsed.key == nil {
            checks.append(.init(title: parsed.title, kind: .key, message: "No key set. Add {key: G} so the cue card can show it."))
        }
        if parsed.moods.isEmpty {
            checks.append(.init(title: parsed.title, kind: .mood,
                                message: "No mood tags, so it won't show on the mood grid. Edit it to add one."))
        }
        for mood in parsed.moods where !moodKeys.contains(MoodLibrary.normalized(mood)) {
            checks.append(.init(title: parsed.title, kind: .mood,
                                message: "\u{201C}\(mood)\u{201D} isn't one of your moods yet. Add it in Moods to see this song there."))
        }
        return checks
    }

    /// Text compared for duplicates: trimmed, Windows line endings normalised, and without
    /// any {language:} line (so a song re-imported from a language folder still matches).
    static func duplicateKey(_ source: String) -> String {
        SourceEditing.setting(.language, to: nil, in: source)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The starter text shown in the paste screen.
    static let template = """
    {title: Song Title}
    {artist: Artist}
    {key: G}
    {duration: 3:30}
    {mood: Campfire, Jolly}

    {comment: Verse 1}
    [G]Put each chord in [C]brackets right be[D]fore the word
    [Em]नेपाली वा हिन्दी [C]पनि लेख्न [D]सकिन्छ

    {start_of_chorus}
    [C]This is the [G]chorus
    {end_of_chorus}
    """
}
