//
//  ChordShapes.swift
//  Moodchords
//
//  Guitar fingerings for chord names, for the chord chart on the song page.
//  Common open chords come from a hand-checked table; anything else is built from the
//  standard movable barre shapes ("E shape" rooted on the 6th string, "A shape" on the 5th).
//

import Foundation

/// How to play a chord: one fret per string, low E (6th) to high e (1st).
nonisolated struct ChordShape: Equatable, Sendable {
    /// nil = don't play the string (x), 0 = open, n = fret n.
    var frets: [Int?]
    /// A fret held down across several strings by one finger, if any.
    var barre: Int?

    /// The lowest fretted note, used to decide which part of the neck to draw.
    var lowestFret: Int { frets.compactMap { $0 }.filter { $0 > 0 }.min() ?? 0 }
    var highestFret: Int { frets.compactMap { $0 }.max() ?? 0 }

    /// "x32010" style, for tests and debugging.
    var tab: String {
        frets.map { $0.map { $0 < 10 ? String($0) : "(\($0))" } ?? "x" }.joined()
    }

    init(_ tab: String, barre: Int? = nil) {
        frets = tab.map { $0 == "x" ? nil : Int(String($0)) }
        self.barre = barre
    }

    init(frets: [Int?], barre: Int?) {
        self.frets = frets
        self.barre = barre
    }
}

/// A chord name taken apart: root, quality and optional bass note ("F#m7/E").
nonisolated struct ChordName: Equatable, Sendable {
    var root: Int          // 0 = C … 11 = B
    var quality: String    // normalised: "", "m", "7", "m7", "maj7", "sus4", …
    var bass: Int?

    private static let noteValues: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

    init?(_ name: String) {
        var rest = Substring(name.trimmingCharacters(in: .whitespaces))
        guard let letter = rest.first, let value = Self.noteValues[letter] else { return nil }
        rest = rest.dropFirst()
        var root = value
        if rest.first == "#" { root += 1; rest = rest.dropFirst() } else if rest.first == "b" { root -= 1; rest = rest.dropFirst() }
        self.root = (root + 12) % 12

        var qualityText = String(rest)
        bass = nil
        if let slash = qualityText.firstIndex(of: "/") {
            let bassText = qualityText[qualityText.index(after: slash)...]
            qualityText = String(qualityText[..<slash])
            if let bassLetter = bassText.first, let bassValue = Self.noteValues[bassLetter] {
                var b = bassValue
                if bassText.dropFirst().first == "#" { b += 1 } else if bassText.dropFirst().first == "b" { b -= 1 }
                bass = (b + 12) % 12
            }
        }
        quality = Self.normalise(qualityText)
    }

    /// Maps the many ways of writing a chord quality onto the ones we have shapes for.
    static func normalise(_ text: String) -> String {
        let q = text.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        let table: [String: String] = [
            "": "", "M": "", "maj": "",
            "m": "m", "min": "m", "-": "m",
            "7": "7", "dom7": "7",
            "maj7": "maj7", "M7": "maj7", "Δ": "maj7", "Δ7": "maj7", "ma7": "maj7",
            "m7": "m7", "min7": "m7", "-7": "m7",
            "sus4": "sus4", "sus": "sus4", "sus2": "sus2", "2": "sus2",
            "7sus4": "7sus4", "7sus": "7sus4",
            "add9": "add9", "add2": "add9",
            "6": "6", "m6": "m6",
            "9": "9", "m9": "m7", "maj9": "maj7", "11": "7sus4", "13": "7",
            "dim": "dim", "°": "dim", "o": "dim", "dim7": "dim7", "°7": "dim7", "o7": "dim7",
            "m7b5": "m7b5", "ø": "m7b5", "ø7": "m7b5",
            "aug": "aug", "+": "aug", "5": "5",
            "mmaj7": "m", "madd9": "m", "7b9": "7", "7#9": "7",
        ]
        if let known = table[q] { return known }
        // Unknown extensions: fall back to the basic triad.
        return q.hasPrefix("m") && !q.hasPrefix("maj") ? "m" : ""
    }
}

nonisolated enum ChordShapes {
    /// The shape to show for a chord name, or nil if it isn't a chord we can read.
    static func shape(for name: String) -> ChordShape? {
        let cleaned = name.trimmingCharacters(in: .whitespaces)
        if let open = openShapes[cleaned] { return open }
        guard let chord = ChordName(cleaned) else { return nil }
        // A slash chord we don't know as a whole is shown as its main chord.
        let key = noteName(chord.root) + chord.quality
        if let open = openShapes[key] { return open }
        return movableShape(root: chord.root, quality: chord.quality)
    }

    // MARK: Open chords

    private static let openShapes: [String: ChordShape] = [
        // Major
        "C": .init("x32010"), "D": .init("xx0232"), "E": .init("022100"), "G": .init("320003"),
        "A": .init("x02220"), "F": .init("133211", barre: 1), "B": .init("x24442", barre: 2),
        // Minor
        "Am": .init("x02210"), "Dm": .init("xx0231"), "Em": .init("022000"),
        "Bm": .init("x24432", barre: 2), "F#m": .init("244222", barre: 2),
        // Seventh
        "A7": .init("x02020"), "B7": .init("x21202"), "C7": .init("x32310"),
        "D7": .init("xx0212"), "E7": .init("020100"), "G7": .init("320001"),
        // Major seventh
        "Cmaj7": .init("x32000"), "Dmaj7": .init("xx0222"), "Emaj7": .init("021100"),
        "Fmaj7": .init("xx3210"), "Gmaj7": .init("320002"), "Amaj7": .init("x02120"),
        // Minor seventh
        "Am7": .init("x02010"), "Dm7": .init("xx0211"), "Em7": .init("022030"), "Bm7": .init("x20202"),
        // Suspended / added
        "Asus4": .init("x02230"), "Dsus4": .init("xx0233"), "Esus4": .init("022200"),
        "Asus2": .init("x02200"), "Dsus2": .init("xx0230"),
        "A7sus4": .init("x02030"), "Cadd9": .init("x32033"), "Gsus4": .init("330013"),
        // Sixths
        "A6": .init("x02222"), "C6": .init("x32210"), "D6": .init("xx0202"), "E6": .init("022120"),
        // Common slash chords
        "G/B": .init("x20003"), "C/G": .init("332010"), "C/E": .init("032010"),
        "D/F#": .init("200232"), "Am/G": .init("302210"), "Em/D": .init("xx0000"),
    ]

    // MARK: Movable barre shapes

    /// Offsets from the barre fret, low E to high e; nil = muted.
    private static let eShape: [String: [Int?]] = [
        "": [0, 2, 2, 1, 0, 0], "m": [0, 2, 2, 0, 0, 0], "7": [0, 2, 0, 1, 0, 0],
        "m7": [0, 2, 0, 0, 0, 0], "maj7": [0, nil, 1, 1, 0, nil], "sus4": [0, 2, 2, 2, 0, 0],
        "7sus4": [0, 2, 0, 2, 0, 0], "5": [0, 2, 2, nil, nil, nil], "6": [0, nil, -1, 1, 0, nil],
        "m6": [0, nil, -1, 0, 0, nil],
    ]
    private static let aShape: [String: [Int?]] = [
        "": [nil, 0, 2, 2, 2, 0], "m": [nil, 0, 2, 2, 1, 0], "7": [nil, 0, 2, 0, 2, 0],
        "m7": [nil, 0, 2, 0, 1, 0], "maj7": [nil, 0, 2, 1, 2, 0], "sus4": [nil, 0, 2, 2, 3, 0],
        "sus2": [nil, 0, 2, 2, 0, 0], "7sus4": [nil, 0, 2, 0, 3, 0], "dim": [nil, 0, 1, 2, 1, nil],
        "m7b5": [nil, 0, 1, 0, 1, nil], "dim7": [nil, 0, 1, 2, 1, 2], "aug": [nil, 0, 3, 2, 2, 1],
        "6": [nil, 0, 2, 2, 2, 2], "m6": [nil, 0, 2, 2, 1, 2], "9": [nil, 0, -1, 0, 0, 0],
        "add9": [nil, 0, 2, 4, 0, 0], "5": [nil, 0, 2, 2, nil, nil],
    ]

    /// Builds the chord from the E or A shape, whichever sits lower on the neck.
    static func movableShape(root: Int, quality: String) -> ChordShape? {
        var options: [ChordShape] = []
        if let offsets = eShape[quality] { options.append(place(offsets, at: (root - 4 + 12) % 12)) }
        if let offsets = aShape[quality] { options.append(place(offsets, at: (root - 9 + 12) % 12)) }
        // Keep shapes playable: a negative offset at fret 0 would need a fret below the nut.
        let playable = options.compactMap { $0 }.filter { shape in shape.frets.allSatisfy { ($0 ?? 0) >= 0 } }
        return playable.min { $0.highestFret < $1.highestFret }
    }

    private static func place(_ offsets: [Int?], at fret: Int) -> ChordShape {
        // At fret 0 the barre is the nut (an open chord); otherwise one finger barres the fret.
        let base = fret == 0 ? 0 : fret
        let frets = offsets.map { $0.map { base + $0 } }
        let barred = frets.filter { $0 == base }.count >= 2
        return ChordShape(frets: frets, barre: base > 0 && barred ? base : nil)
    }

    private static let names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    static func noteName(_ value: Int) -> String { names[(value % 12 + 12) % 12] }
}
