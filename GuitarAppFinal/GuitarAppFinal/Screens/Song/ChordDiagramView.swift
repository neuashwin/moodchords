import SwiftUI

/// A chord box: name, x/o marks, four frets, dots, and a bar for barre chords.
struct ChordDiagramView: View {
    var name: String
    var shape: ChordShape?

    init(name: String) {
        self.name = name
        shape = ChordShapes.shape(for: name)
    }

    /// Four frets are drawn; shapes higher up the neck start at their lowest fret.
    private var startFret: Int {
        guard let shape, shape.highestFret > 4 else { return 1 }
        return max(shape.barre ?? shape.lowestFret, 1)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(Theme.font(size: 17, weight: .heavy))
                .foregroundStyle(Theme.chord)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let shape {
                HStack(alignment: .top, spacing: 0) {
                    // "5fr" when the shape doesn't start at the nut.
                    Text(startFret > 1 ? "\(startFret)fr" : "")
                        .font(Theme.font(size: 9, weight: .semibold, mono: true))
                        .foregroundStyle(Theme.fg2)
                        .frame(width: 16, alignment: .trailing)
                        .padding(.top, DiagramGrid.marksHeight + 2)
                    // The marks row and the grid share the same string positions.
                    DiagramGrid(shape: shape, startFret: startFret)
                        .frame(width: DiagramGrid.size.width, height: DiagramGrid.size.height)
                    Color.clear.frame(width: 16, height: 1)
                }
            } else {
                Text("No diagram")
                    .font(Theme.font(size: 11))
                    .foregroundStyle(Theme.fg3)
                    .frame(width: 62, height: 90)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let shape else { return "\(name), no diagram" }
        let strings = ["low E", "A", "D", "G", "B", "high E"]
        let parts = zip(strings, shape.frets).map { string, fret in
            switch fret {
            case nil: "\(string) muted"
            case 0: "\(string) open"
            case let fret?: "\(string) fret \(fret)"
            }
        }
        return "\(name): " + parts.joined(separator: ", ")
    }
}

/// The x/o marks, strings, frets, dots and barre, drawn with Canvas. The grid sits inside a
/// small margin so dots on the outer strings aren't cut off.
private struct DiagramGrid: View {
    var shape: ChordShape
    var startFret: Int

    static let margin: CGFloat = 8
    static let marksHeight: CGFloat = 14
    static let gridSize = CGSize(width: 62, height: 74)
    static var size: CGSize {
        CGSize(width: gridSize.width + margin * 2, height: gridSize.height + marksHeight + 4)
    }

    var body: some View {
        Canvas { context, _ in
            let left = Self.margin
            let top = Self.marksHeight + 2
            let width = Self.gridSize.width
            let height = Self.gridSize.height
            let stringGap = width / 5
            let fretGap = height / 4
            let line = Theme.fg3
            let ink = Theme.fg

            // x (don't play) and o (open) above each string.
            for string in 0..<6 {
                let mark = shape.frets[string] == nil ? "×" : shape.frets[string] == 0 ? "○" : nil
                if let mark {
                    context.draw(Text(mark).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.fg2),
                                 at: CGPoint(x: left + CGFloat(string) * stringGap, y: Self.marksHeight / 2))
                }
            }

            // Strings (vertical) and frets (horizontal).
            for string in 0..<6 {
                let x = left + CGFloat(string) * stringGap
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: top)); $0.addLine(to: CGPoint(x: x, y: top + height)) },
                               with: .color(line), lineWidth: 1.5)
            }
            for fret in 0...4 {
                let y = top + CGFloat(fret) * fretGap
                context.stroke(Path { $0.move(to: CGPoint(x: left, y: y)); $0.addLine(to: CGPoint(x: left + width, y: y)) },
                               with: .color(line), lineWidth: 1.5)
            }
            // The nut: a thick top edge when the shape starts at the first fret.
            if startFret == 1 {
                context.fill(Path(roundedRect: CGRect(x: left - 1, y: top - 2, width: width + 2, height: 4), cornerRadius: 2),
                             with: .color(ink))
            }

            func centre(string: Int, fret: Int) -> CGPoint {
                CGPoint(x: left + CGFloat(string) * stringGap, y: top + (CGFloat(fret - startFret) + 0.5) * fretGap)
            }

            // Barre: one bar from the lowest barred string to the 1st string.
            if let barre = shape.barre, (startFret...(startFret + 3)).contains(barre),
               let first = shape.frets.firstIndex(where: { $0 == barre }) {
                let left = centre(string: first, fret: barre)
                let right = centre(string: 5, fret: barre)
                context.fill(Path(roundedRect: CGRect(x: left.x - 6, y: left.y - 6.5,
                                                      width: right.x - left.x + 12, height: 13), cornerRadius: 6.5),
                             with: .color(ink))
            }
            // Dots for the other fretted notes.
            for (string, fret) in shape.frets.enumerated() {
                guard let fret, fret > 0, fret != shape.barre,
                      (startFret...(startFret + 3)).contains(fret) else { continue }
                let c = centre(string: string, fret: fret)
                context.fill(Path(ellipseIn: CGRect(x: c.x - 6.5, y: c.y - 6.5, width: 13, height: 13)), with: .color(ink))
            }
        }
    }
}

/// Every chord in a song as a wrapping grid of diagrams.
struct ChordChart: View {
    var chords: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 4)], spacing: 14) {
            ForEach(chords, id: \.self) { chord in
                ChordDiagramView(name: chord)
            }
        }
    }
}

#Preview {
    ScrollView {
        ChordChart(chords: ["G", "C", "D", "Em7", "F", "Bb", "C#m", "F#m", "A7sus4", "G/B", "Cadd9", "Ebmaj7"])
            .padding()
    }
    .background(Theme.bg)
}
