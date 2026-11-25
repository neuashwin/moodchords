import SwiftUI

/// Turns a mood's hue into its tile colour.
///
/// The design defines every mood colour as `oklch(0.80 0.11 hue)`, so a mood only
/// needs to store its hue (0–360) and custom moods can use any hue.
nonisolated enum MoodColor {
    static let lightness = 0.80
    static let chroma = 0.11

    /// sRGB components (0...1) for a hue, using the standard OKLCH → OKLab → linear sRGB maths.
    static func rgb(hue: Double) -> (red: Double, green: Double, blue: Double) {
        let radians = hue * .pi / 180
        let a = chroma * cos(radians)
        let b = chroma * sin(radians)

        // OKLab → LMS (cube roots), then cube.
        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)

        // LMS → linear sRGB.
        let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return (gammaEncode(r), gammaEncode(g), gammaEncode(bl))
    }

    /// The colour as a 0xRRGGBB value (handy for tests and debugging).
    static func hex(hue: Double) -> UInt32 {
        let c = rgb(hue: hue)
        func byte(_ v: Double) -> UInt32 { UInt32((v * 255).rounded()) }
        return byte(c.red) << 16 | byte(c.green) << 8 | byte(c.blue)
    }

    /// Linear light → sRGB gamma, clamped to the displayable range.
    private static func gammaEncode(_ x: Double) -> Double {
        let v = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        return min(max(v, 0), 1)
    }
}

extension Color {
    /// The mood tile colour for a hue (same in light and dark mode).
    init(moodHue hue: Double) {
        let c = MoodColor.rgb(hue: hue)
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue)
    }
}

/// The look of a mood: what tiles and chips need to draw it.
/// Step 2.2 seeds the `Mood` records from `defaults`.
struct MoodSwatch: Identifiable, Hashable {
    var name: String
    var symbol: String
    var hue: Double
    var subtitle: String?

    var id: String { name }
    var color: Color { Color(moodHue: hue) }

    static let defaults: [MoodSwatch] = [
        MoodSwatch(name: "Romantic", symbol: "heart.fill", hue: 10),
        MoodSwatch(name: "Dance", symbol: "figure.dance", hue: 290),
        MoodSwatch(name: "Jolly", symbol: "face.smiling.inverse", hue: 95),
        MoodSwatch(name: "Campfire", symbol: "flame.fill", hue: 50),
        MoodSwatch(name: "Sad", symbol: "cloud.rain.fill", hue: 245),
        MoodSwatch(name: "Devotional", symbol: "hands.and.sparkles.fill", hue: 80),
        MoodSwatch(name: "Nostalgic", symbol: "radio.fill", hue: 200),
        MoodSwatch(name: "Party", symbol: "party.popper.fill", hue: 330),
        MoodSwatch(name: "Festival", symbol: "fireworks", hue: 150, subtitle: "Dashain · Tihar"),
    ]
}

// MARK: - Glow background

/// The soft radial mood glow at the top of a screen, over a base colour.
///
/// Design CSS: `radial-gradient(110% 50% at 50% -6%, mood 45%|22%, transparent 72%), bg`.
/// The ellipse is 110% of the width and 50% of the height (as radii), centred just above the top edge.
struct MoodGlowBackground: View {
    var color: Color
    var base: Color = Theme.bg

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // EllipticalGradient's ellipse fills its frame, so make the frame twice the CSS radii.
            let glowWidth = size.width * 1.1 * 2
            let glowHeight = size.height * 0.5 * 2
            EllipticalGradient(
                colors: [color.opacity(colorScheme == .dark ? 0.22 : 0.45), color.opacity(0)],
                center: .center,
                startRadiusFraction: 0,
                // Fractions are of the whole frame (0.5 = the frame's edge), so 72% of the radius is 0.36.
                endRadiusFraction: 0.36
            )
            .frame(width: glowWidth, height: glowHeight)
            .position(x: size.width / 2, y: -0.06 * size.height)
        }
        .background(base)
        .ignoresSafeArea()
    }
}

extension View {
    /// Puts the mood glow behind this view, filling the whole screen.
    func moodGlow(_ color: Color, base: Color = Theme.bg) -> some View {
        background { MoodGlowBackground(color: color, base: base) }
    }
}
