//
//  ChordSheetView.swift
//  Moodchords
//
//  Renders parsed lines with each chord drawn above the text it belongs to.
//  Play mode reuses `ChordLineView` for each line.
//

import SwiftUI
import UIKit

struct ChordSheetView: View {
    let lines: [SongLine]
    var fontSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.45) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {
                case .blank:
                    Color.clear.frame(height: fontSize * 0.4)
                case .section(let name):
                    SectionHeading(name: name, fontSize: fontSize)
                case .note(let text):
                    NoteLine(text: text, fontSize: fontSize)
                case .lyrics(let segments):
                    ChordLineView(segments: segments, fontSize: fontSize)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "VERSE 1", small mono caps.
struct SectionHeading: View {
    let name: String
    var fontSize: CGFloat = 18
    var color: Color = .secondary

    var body: some View {
        Text(name.uppercased())
            .font(.system(size: max(fontSize * 0.62, 11), weight: .medium, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(color)
            .padding(.top, fontSize * 0.5)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Website notes ("Video lesson – …"): small, muted, not lyrics.
struct NoteLine: View {
    let text: String
    var fontSize: CGFloat = 18

    var body: some View {
        Text(text)
            .font(.system(size: max(fontSize * 0.72, 12)))
            .italic()
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One lyric line: each word-piece with its chord (if any) above it.
struct ChordLineView: View {
    let segments: [ChordSegment]
    let fontSize: CGFloat
    /// Lyric colour; chords use the tint unless `chordColor` is set.
    var textColor: Color = .primary
    var chordColor: Color?

    var body: some View {
        let pieces = ChordSheetLayout.pieces(from: segments)
        let advances = ChordSpacing.minimumWidths(for: pieces, fontSize: fontSize)

        ChordLineLayout(advances: advances,
                        hasChord: pieces.map { $0.chord != nil },
                        hasText: pieces.map { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty },
                        // A chord can sit mid-word ("ton[C]ight"): never wrap inside a word.
                        startsWord: pieces.indices.map { index in
                            index == 0 || pieces[index - 1].text.isEmpty
                                || pieces[index - 1].text.last?.isWhitespace == true
                        })
        {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                // Two subviews per piece: its chord (or an empty placeholder), then its text.
                Text(piece.chord ?? "")
                    .font(ChordSpacing.chordFont(fontSize))
                    .foregroundStyle(chordColor.map(AnyShapeStyle.init) ?? AnyShapeStyle(.tint))
                    .fixedSize()
                Text(piece.text)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(textColor)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(pieces))
    }

    /// VoiceOver reads the words, then the chords: "Sparks are rising. Chords: G, C".
    /// (Chords can sit mid-word, so reading them inline would break the words apart.)
    private func accessibilityText(_ pieces: [ChordSegment]) -> String {
        let words = pieces.map(\.text).joined().trimmingCharacters(in: .whitespaces)
        let chords = pieces.compactMap(\.chord)
        guard !chords.isEmpty else { return words }
        let chordList = "Chords: " + chords.joined(separator: ", ")
        return words.isEmpty ? chordList : words + ". " + chordList
    }
}

/// Lays out (chord, text) pairs left to right, wrapping between words.
///
/// - Each piece advances by its precomputed width, so chords never collide.
/// - A piece moves to the next row if its text or its chord would run past the edge,
///   so chords are never cut off.
/// - A row only reserves space for chords if it has at least one, so wrapped lines don't
///   leave an empty chord row.
struct ChordLineLayout: Layout {
    var advances: [CGFloat]
    var hasChord: [Bool]
    /// Whether each piece has words; a row of chords only (an intro line) needs no lyric row.
    var hasText: [Bool] = []
    /// Whether a new row may start at each piece (false inside a word split by a chord).
    var startsWord: [Bool] = []
    var rowSpacing: CGFloat = 2

    private struct Row {
        var range: Range<Int>
        var hasChord: Bool
        var hasText: Bool
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let (rows, widest) = arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let metrics = lineMetrics(subviews)
        let height = rows.reduce(0) { $0 + rowHeight($1, metrics) } + rowSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (rows, _) = arrange(maxWidth: bounds.width, subviews: subviews)
        let metrics = lineMetrics(subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let textY = y + (row.hasChord ? metrics.chord : 0)
            for index in row.range {
                subviews[2 * index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                subviews[2 * index + 1].place(at: CGPoint(x: x, y: textY), proposal: .unspecified)
                x += advance(index, subviews)
            }
            y += rowHeight(row, metrics) + rowSpacing
        }
    }

    private func advance(_ index: Int, _ subviews: Subviews) -> CGFloat {
        let text = subviews[2 * index + 1].sizeThatFits(.unspecified).width
        return max(index < advances.count ? advances[index] : text, text)
    }

    /// Splits pieces into rows that fit `maxWidth`.
    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> ([Row], CGFloat) {
        let count = subviews.count / 2
        var rows: [Row] = []
        var start = 0
        var x: CGFloat = 0
        var widest: CGFloat = 0
        /// Where the current word began on this row, and the x position there.
        var wordStart = 0
        var wordStartX: CGFloat = 0

        for index in 0..<count {
            let width = advance(index, subviews)
            let chordWidth = hasChord[safe: index] == true ? subviews[2 * index].sizeThatFits(.unspecified).width : 0
            let textWidth = subviews[2 * index + 1].sizeThatFits(.unspecified).width
            let canBreak = startsWord.isEmpty || startsWord[safe: index] == true
            if canBreak {
                wordStart = index
                wordStartX = x
            }
            // Trailing spaces may hang past the edge; the visible word and the chord may not.
            let visible = max(chordWidth, textWidth - trailingSpaceAllowance(textWidth))
            if index > start, x + visible > maxWidth {
                // Break at the start of this word (which may be an earlier piece).
                let breakAt = canBreak ? index : wordStart
                if breakAt > start {
                    rows.append(row(start..<breakAt, hasChord: hasChord(in: start..<breakAt)))
                    x -= canBreak ? x : wordStartX
                    start = breakAt
                    wordStartX = 0
                }
            }
            widest = max(widest, min(x + max(width, visible), maxWidth))
            x += width
        }
        let rowHasChord = hasChord(in: start..<count)
        if count > 0 { rows.append(row(start..<count, hasChord: rowHasChord)) }
        return (rows, widest)
    }

    private func hasChord(in range: Range<Int>) -> Bool {
        range.contains { hasChord[safe: $0] == true }
    }

    private func row(_ range: Range<Int>, hasChord: Bool) -> Row {
        // Without `hasText` information, assume every row has words.
        let text = hasText.isEmpty || range.contains { hasText[safe: $0] == true }
        return Row(range: range, hasChord: hasChord, hasText: text || !hasChord)
    }

    /// Roughly one space's width: a word's trailing space may poke past the right edge.
    private func trailingSpaceAllowance(_ width: CGFloat) -> CGFloat { min(width, 6) }

    private struct Metrics {
        var chord: CGFloat
        var text: CGFloat
    }

    private func lineMetrics(_ subviews: Subviews) -> Metrics {
        var chord: CGFloat = 0
        var text: CGFloat = 0
        for index in 0..<(subviews.count / 2) {
            chord = max(chord, subviews[2 * index].sizeThatFits(.unspecified).height)
            text = max(text, subviews[2 * index + 1].sizeThatFits(.unspecified).height)
        }
        return Metrics(chord: chord, text: text)
    }

    private func rowHeight(_ row: Row, _ metrics: Metrics) -> CGFloat {
        (row.hasChord ? metrics.chord : 0) + (row.hasText ? metrics.text : 0)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Works out where extra space is needed so a chord never runs into the next chord.
/// Space goes just before the next chord's word, the way printed chord sheets do it.
enum ChordSpacing {
    static func chordFont(_ size: CGFloat) -> Font {
        .system(size: size * 0.82, weight: .heavy)
    }

    static func minimumWidths(for pieces: [ChordSegment], fontSize: CGFloat) -> [CGFloat] {
        let lyricFont = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let chordUIFont = UIFont.systemFont(ofSize: fontSize * 0.82, weight: .heavy)
        let gap = fontSize * 0.4

        let textWidths = pieces.map { width($0.text, lyricFont) }
        var minWidths = textWidths
        let chordIndices = pieces.indices.filter { pieces[$0].chord != nil }

        for (current, next) in zip(chordIndices, chordIndices.dropFirst()) {
            let needed = width(pieces[current].chord!, chordUIFont) + gap
            let available = textWidths[current..<next].reduce(0, +)
            if needed > available {
                minWidths[next - 1] += needed - available
            }
        }
        // The last chord on a line has nothing after it to overlap, but it still needs its own room.
        if let last = chordIndices.last {
            let needed = width(pieces[last].chord!, chordUIFont)
            let available = textWidths[last...].reduce(0, +)
            if needed > available { minWidths[pieces.count - 1] += needed - available }
        }
        return minWidths
    }

    private static func width(_ text: String, _ font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

/// Places subviews left to right, wrapping to a new row when the width runs out.
struct FlowLayout: Layout {
    var rowSpacing: CGFloat = 2
    /// Gap between items on the same row (chips use one; lyric words carry their own spacing).
    var itemSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(maxWidth: bounds.width, subviews: subviews).positions
        for (subview, point) in zip(subviews, positions) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x + size.width)
            x += size.width + itemSpacing
        }
        return (positions, CGSize(width: widest, height: y + rowHeight))
    }
}

#Preview {
    let song = try! ChordProParser.parse("""
    {title: Campfire Night}
    Video lesson - https://example.com/lesson
    [Verse 1]
    [G]Sparks are rising [C]up into the [G]sky, and the embers drift a[Em]long
    [Em]Friends around the [C]fire and the [D]night rolls by       [A7sus4]
    [Chorus]
    [C] [G] [D] [G]
    [C]Sing it loud, [G]sing it slow
    [Am]साँझ परेपछि [F]पहाड हेर्छु
    """)
    ScrollView { ChordSheetView(lines: song.lines).padding().tint(.orange) }
}
