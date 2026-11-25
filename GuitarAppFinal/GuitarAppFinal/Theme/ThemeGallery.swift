import SwiftUI

/// A preview-only page showing every design token and component, to compare against
/// the design file's style guide. Not used in the app itself.
struct ThemeGallery: View {
    /// Start scrolled to the bottom, so a preview snapshot shows the components.
    var startAtBottom = false

    @State private var tab: AppTab = .moods

    private let campfire = MoodSwatch.defaults[3]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                colours
                typeScale
                moodGrid
                chips
                buttons
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .defaultScrollAnchor(startAtBottom ? .bottom : .top)
        .moodGlow(campfire.color)
        .overlay(alignment: .bottom) {
            GlassTabBar(selection: $tab)
                .padding(.bottom, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Spacer()
                GlassCircleButton(symbol: "magnifyingglass", accessibilityLabel: "Search") {}
                GlassCircleButton(symbol: "plus", accessibilityLabel: "Add song") {}
            }
            Text("Moodchords")
                .themeFont(.largeTitle)
                .foregroundStyle(Theme.fg)
            Text("What's the vibe tonight?")
                .themeFont(.body)
                .foregroundStyle(Theme.fg2)
        }
    }

    private var colours: some View {
        section("Colour tokens") {
            let tokens: [(String, Color)] = [
                ("bg", Theme.bg), ("stage", Theme.stage), ("sheet", Theme.sheet),
                ("fg", Theme.fg), ("fg2", Theme.fg2), ("fg3", Theme.fg3),
                ("card", Theme.card), ("card2", Theme.card2), ("chip", Theme.chip),
                ("chord", Theme.chord), ("ok", Theme.ok), ("danger", Theme.danger),
            ]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(tokens, id: \.0) { name, color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color)
                            .frame(height: 40)
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 0.5) }
                        Text(name)
                            .themeFont(.monoSmall)
                            .foregroundStyle(Theme.fg2)
                    }
                }
            }
        }
    }

    private var typeScale: some View {
        section("Type scale · SF Pro + SF Mono") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Campfire Night").themeFont(.title)
                Text("Who's listening?").themeFont(.headline)
                Text("One tap. You can change it on the song list.")
                    .themeFont(.body)
                    .foregroundStyle(Theme.fg2)
                SpecLabel("Cue card · Key G · Capo 2", color: Theme.fg)
                Text("साँझको गीत").themeFont(.title)
                HStack(spacing: 4) {
                    Text("G").foregroundStyle(Theme.chord)
                    Text("Sparks are rising").foregroundStyle(Theme.fg)
                }
                .font(Theme.font(size: 23, weight: .heavy))
            }
            .foregroundStyle(Theme.fg)
        }
    }

    private var moodGrid: some View {
        section("Mood palette · oklch(0.80 0.11 h)") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(MoodSwatch.defaults.enumerated()), id: \.element.id) { index, mood in
                    MoodTile(mood: mood, countLabel: index == 2 ? "No songs yet" : "\(index + 3) songs")
                }
                NewMoodTile()
            }
        }
    }

    private var chips: some View {
        section("Chips") {
            HStack(spacing: 8) {
                Chip(title: campfire.name, style: .mood(campfire))
                Chip(title: "Friends")
                Chip(title: "Mixed", style: .selected)
            }
        }
    }

    private var buttons: some View {
        section("Accent pill") {
            AccentPill(title: "Surprise me", subtitle: "From 12 songs you're ready to play") {}
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SpecLabel(title)
            content()
        }
    }
}

#Preview("Light") {
    ThemeGallery()
        .preferredColorScheme(.light)
}

#Preview("Dark (stage)") {
    ThemeGallery()
        .preferredColorScheme(.dark)
}

#Preview("Light · components") {
    ThemeGallery(startAtBottom: true)
        .preferredColorScheme(.light)
}

#Preview("Dark · components") {
    ThemeGallery(startAtBottom: true)
        .preferredColorScheme(.dark)
}
