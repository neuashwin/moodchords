import SwiftUI
import UIKit

// MARK: - Colour tokens

/// The Moodchords design tokens (from `M2-PLAN.md` §2 / the design file's `MODES`).
/// Every colour has a light and a dark ("stage") value and follows the system appearance.
enum Theme {
    /// Screen background.
    static let bg = Color(light: 0xEFE9E0, dark: 0x15110E)
    /// Play mode / deepest surface.
    static let stage = Color(light: 0xF7F2EA, dark: 0x0C0907)
    /// Sheets and editors.
    static let sheet = Color(light: 0xFAF6F0, dark: 0x241D18)

    /// Primary text.
    static let fg = Color(light: 0x1C1713, dark: 0xF7F0E8)
    /// Secondary text.
    static let fg2 = Color(light: 0x5C534A, dark: 0xB9AEA3)
    /// Tertiary text and borders.
    static let fg3 = Color(light: 0xA99F94, dark: 0x62584F)

    static let card = Color(light: (0xFFFFFF, 0.6), dark: (0xFFFFFF, 0.055))
    static let card2 = Color(light: (0xFFFFFF, 1), dark: (0xFFFFFF, 0.08))
    /// Hairlines (0.5 pt borders).
    static let line = Color(light: (0x1C1713, 0.10), dark: (0xFFFFFF, 0.09))
    static let chip = Color(light: (0x1C1713, 0.065), dark: (0xFFFFFF, 0.085))
    /// Tint layered on floating glass (buttons, tab bar).
    static let glass = Color(light: (0xFFFFFF, 0.62), dark: (0x302720, 0.62))

    /// Chord names: burnt orange on light, amber on stage. Same hue, so they read as one system.
    static let chord = Color(light: 0xB4430A, dark: 0xFFA552)
    static let ok = Color(light: 0x1C7443, dark: 0x6EE29C)
    static let danger = Color(light: 0xB42318, dark: 0xFF8B7B)
    /// Soft fills behind success / error messages (design okbg / errbg).
    static let okBackground = Color(light: (0xCDEBD3, 1), dark: (0x5AD282, 0.17))
    static let errorBackground = Color(light: (0xFBE7E3, 1), dark: (0xFF6450, 0.13))

    /// Dark ink used on every mood tile (AA on all mood colours, in both modes).
    static let moodInk = Color(hex: 0x1E1915)

    /// The orange accent (Surprise me, Play): a top-to-bottom gradient.
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0xEE6A1F), Color(hex: 0xC2440A)],
        startPoint: .top,
        endPoint: .bottom
    )
    /// Colour of the accent's drop shadow.
    static let accentShadow = Color(hex: 0xC2440A)
}

// MARK: - Fonts

/// Every text style in the design. Views ask for `Theme.font(.title)` instead of
/// hard-coding fonts, so swapping SF Pro for Barlow / DM Mono later is a change in one place.
enum ThemeFont {
    case largeTitle     // "Moodchords" 42/800
    case title          // song title 34/800
    case sheetTitle     // "Who's listening?" 32/800
    case headline       // 20/700
    case tileName       // mood tile name 21/700
    case body           // 17/500
    case bodyStrong     // 17/700
    case callout        // 14/600
    case chip           // 14/700
    case tabLabel       // 11/600
    case mono           // spec labels 12/500 mono
    case monoSmall      // 10/500 mono

    var size: CGFloat {
        switch self {
        case .largeTitle: 42
        case .title: 34
        case .sheetTitle: 32
        case .tileName: 21
        case .headline: 20
        case .body, .bodyStrong: 17
        case .callout, .chip: 14
        case .mono: 12
        case .tabLabel: 11
        case .monoSmall: 10
        }
    }

    var weight: Font.Weight {
        switch self {
        case .largeTitle, .title, .sheetTitle: .heavy
        case .headline, .tileName, .bodyStrong, .chip: .bold
        case .callout, .tabLabel: .semibold
        case .body, .mono, .monoSmall: .medium
        }
    }

    var isMono: Bool { self == .mono || self == .monoSmall }

    /// Letter spacing in points (the design gives it in em).
    var tracking: CGFloat {
        switch self {
        case .largeTitle: -0.02 * size
        case .mono, .monoSmall: 0.1 * size
        default: 0
        }
    }
}

extension Theme {
    /// SF Pro stands in for Barlow and SF Mono for DM Mono until the font files are added.
    /// Devanagari text falls back to the system Devanagari font automatically.
    static func font(_ style: ThemeFont) -> Font {
        .system(size: style.size, weight: style.weight, design: style.isMono ? .monospaced : .default)
    }

    /// Big condensed display type (Barlow Condensed in the design), e.g. the "BAJA TA" backdrop.
    static func displayFont(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }

    /// A raw font for one-off sizes (e.g. the big faded icon on a mood tile).
    static func font(size: CGFloat, weight: Font.Weight = .medium, mono: Bool = false) -> Font {
        .system(size: size, weight: weight, design: mono ? .monospaced : .default)
    }
}

extension View {
    /// Applies a design text style: font plus its letter spacing.
    func themeFont(_ style: ThemeFont) -> some View {
        font(Theme.font(style)).tracking(style.tracking)
    }
}

// MARK: - Colour helpers

extension Color {
    /// A colour from a 0xRRGGBB literal.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A colour that switches between a light and a dark value with the system appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(light: (light, 1), dark: (dark, 1))
    }

    /// Same as above, with an opacity for each mode.
    init(light: (hex: UInt32, opacity: Double), dark: (hex: UInt32, opacity: Double)) {
        self.init(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(Color(hex: value.hex, opacity: value.opacity))
        })
    }
}
