import SwiftUI

// MARK: - SpecLabel

/// Mono caps label for specs and counts ("12 SONGS", "KEY", "CAPO 2").
struct SpecLabel: View {
    var text: String
    var color: Color = Theme.fg2

    init(_ text: String, color: Color = Theme.fg2) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .themeFont(.mono)
            .foregroundStyle(color)
    }
}

// MARK: - GlassCircleButton

/// A 44 pt round floating glass button (search, add) for the top right of a screen.
struct GlassCircleButton: View {
    var symbol: String
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.glass).interactive(), in: .circle)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - AccentPill

/// The big orange pill ("Surprise me"): leading icon, title and subtitle, and a round play button.
struct AccentPill: View {
    var title: String
    var subtitle: String?
    var symbol: String = "shuffle"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.font(size: 20, weight: .heavy))
                    if let subtitle {
                        // One line, as in the design; SF Pro is wider than Barlow, so allow a little shrinking.
                        Text(subtitle)
                            .themeFont(.callout)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "play.fill")
                    .font(.system(size: 22))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.22), in: .circle)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(.leading, 22)
            .padding(.trailing, 10)
            .frame(height: 68)
            .background(Theme.accentGradient, in: .capsule)
            // The thin highlight along the top edge.
            .overlay(alignment: .top) {
                Capsule()
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
            }
            .shadow(color: Theme.accentShadow.opacity(0.32), radius: 12, y: 10)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Capsule buttons

/// A full-width 64 pt orange capsule button with an icon ("Paste song").
struct AccentCapsuleButton: View {
    var title: String
    var symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(Theme.font(size: 19, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Theme.accentGradient, in: .capsule)
                .shadow(color: Theme.accentShadow.opacity(0.3), radius: 12, y: 10)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

/// A full-width 64 pt glass capsule button with an icon and an optional mono note ("Import file .TXT · .CHO").
struct GlassCapsuleButton: View {
    var title: String
    var symbol: String
    var note: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .accessibilityHidden(true)
                Text(title)
                    .font(Theme.font(size: 19, weight: .bold))
                if let note {
                    SpecLabel(note)
                }
            }
            .foregroundStyle(Theme.fg)
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.glass).interactive(), in: .capsule)
    }
}

// MARK: - MoodTile

/// A mood in the home grid: 118 pt tall, radius 26, filled with the mood colour.
struct MoodTile: View {
    var mood: MoodSwatch
    /// e.g. "12 SONGS" or "NO SONGS YET".
    var countLabel: String

    /// The count line for a number of songs: "NO SONGS YET", "1 SONG", "12 SONGS".
    static func countLabel(for count: Int) -> String {
        switch count {
        case 0: "No songs yet"
        case 1: "1 song"
        default: "\(count) songs"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: mood.symbol)
                .font(.system(size: 22))
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text(mood.name)
                .themeFont(.tileName)
                .lineLimit(1)
            Text(countLabel.uppercased())
                .font(Theme.font(size: 12, mono: true))
                .tracking(0.48)
                .opacity(0.78)
                .padding(.top, 5)
        }
        .foregroundStyle(Theme.moodInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 118, alignment: .leading)
        // The big faded icon hanging off the bottom-right corner.
        .background(alignment: .bottomTrailing) {
            Image(systemName: mood.symbol)
                .font(.system(size: 96))
                .foregroundStyle(Theme.moodInk.opacity(0.13))
                .offset(x: 16, y: 24)
                .accessibilityHidden(true)
        }
        .background(mood.color)
        .clipShape(.rect(cornerRadius: 26))
        // Tiles always have dark ink on a pastel fill, so draw their content as light mode
        // (some symbols, like the Jolly face, change shape in dark mode otherwise).
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .combine)
    }
}

/// The "New mood" tile at the end of the grid: same size, inset 1.5 pt border.
struct NewMoodTile: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .medium))
            Text("New mood")
                .themeFont(.bodyStrong)
        }
        .foregroundStyle(Theme.fg2)
        .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 118)
        .overlay {
            RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.fg3, lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chip

/// Small rounded labels: plain, selected (check + inverted), or a coloured mood chip.
struct Chip: View {
    enum Style {
        /// Grey chip, e.g. a crowd that isn't selected.
        case plain
        /// A 44 pt tappable option next to `.selected` ones (the song list's crowd row).
        case option
        /// Selected: inverted colours with a check mark (not colour alone).
        case selected
        /// Filled with a mood colour, with the mood's icon.
        case mood(MoodSwatch)
    }

    var title: String
    var style: Style = .plain

    var body: some View {
        switch style {
        case .plain:
            Text(title)
                .font(Theme.font(.callout))
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Theme.chip, in: .capsule)

        case .option:
            Text(title)
                .font(Theme.font(size: 15, weight: .bold))
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(Theme.chip, in: .capsule)

        case .selected:
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(Theme.font(size: 15, weight: .bold))
            }
            .foregroundStyle(Theme.bg)
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .frame(height: 44)
            .background(Theme.fg, in: .capsule)
            .accessibilityAddTraits(.isSelected)

        case .mood(let mood):
            HStack(spacing: 5) {
                Image(systemName: mood.symbol)
                    .font(.system(size: 14))
                Text(title)
                    .font(Theme.font(.chip))
            }
            .foregroundStyle(Theme.moodInk)
            .padding(.leading, 9)
            .padding(.trailing, 12)
            .frame(height: 32)
            .background(mood.color, in: .capsule)
            // Same reason as MoodTile: dark ink on pastel in both modes.
            .environment(\.colorScheme, .light)
        }
    }
}

// MARK: - ReadyMark

/// "Ready to play" shown by shape, not colour alone: a filled check vs. an empty ring.
struct ReadyMark: View {
    var isReady: Bool

    var body: some View {
        Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(isReady ? Theme.ok : Theme.fg3)
            .frame(width: 26, height: 26)
            .accessibilityLabel(isReady ? "Ready to play" : "Still learning")
    }
}

// MARK: - GlassTabBar

/// The app's four tabs.
enum AppTab: String, CaseIterable, Identifiable {
    case moods, favourites, setlists, tuner

    var id: Self { self }

    var title: String {
        switch self {
        case .moods: "Moods"
        case .favourites: "Favourites"
        case .setlists: "Setlists"
        case .tuner: "Tuner"
        }
    }

    /// Outline symbol; the active tab uses the filled variant.
    var symbol: String {
        switch self {
        case .moods: "square.grid.2x2"
        case .favourites: "star"
        case .setlists: "music.note.list"
        case .tuner: "tuningfork"
        }
    }
}

/// The floating glass capsule tab bar. The active tab gets a chip background and a chord-coloured icon.
struct GlassTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isActive = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .symbolVariant(isActive ? .fill : .none)
                            .font(.system(size: 20))
                            .frame(height: 24)
                        Text(tab.title)
                            .themeFont(.tabLabel)
                    }
                    .foregroundStyle(isActive ? Theme.chord : Theme.fg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(isActive ? Theme.chip : .clear, in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 66)
        .glassEffect(.regular.tint(Theme.glass), in: .capsule)
        .shadow(color: .black.opacity(0.16), radius: 15, y: 8)
        .padding(.horizontal, 16)
    }
}
