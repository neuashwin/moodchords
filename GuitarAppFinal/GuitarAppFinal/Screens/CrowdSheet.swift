import SwiftUI
import SwiftData

/// "Who's listening?" (design 2A). Shown as a sheet after tapping a mood; one tap on a
/// crowd (or "Anyone") picks it and closes the sheet.
struct CrowdSheet: View {
    var mood: Mood
    /// All songs; the sheet counts the ones in `mood` for each crowd.
    var songs: [Song]
    var onPick: (CrowdFilter) -> Void

    private var moodSongs: [Song] { MoodLibrary.songs(for: mood, in: songs) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Chip(title: mood.name, style: .mood(mood.swatch))
                SpecLabel(MoodTile.countLabel(for: moodSongs.count))
            }

            Text("Who's listening?")
                .font(Theme.font(.sheetTitle))
                .foregroundStyle(Theme.fg)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)
            Text("One tap. You can change it on the song list.")
                .font(Theme.font(size: 16))
                .foregroundStyle(Theme.fg2)
                .padding(.top, 6)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(Crowd.allCases) { crowd in
                    Button {
                        onPick(.crowd(crowd))
                    } label: {
                        CrowdCard(crowd: crowd, count: moodSongs.filter { $0.matches(.crowd(crowd)) }.count)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 20)

            Button {
                onPick(.anyone)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "infinity")
                        .accessibilityHidden(true)
                    Text("Anyone · all \(Self.songCount(moodSongs.count))")
                }
                    .font(Theme.font(.bodyStrong))
                    .foregroundStyle(Theme.fg)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.chip, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    /// "0 songs", "1 song", "3 songs".
    static func songCount(_ count: Int) -> String {
        count == 1 ? "1 song" : "\(count) songs"
    }
}

/// One crowd option: icon and count on top, name and subtitle below.
private struct CrowdCard: View {
    var crowd: Crowd
    var count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: crowd.symbol)
                    .font(.system(size: 24, weight: .medium))
                    .frame(height: 30, alignment: .topLeading)
                    .accessibilityHidden(true)
                Spacer()
                Text(CrowdSheet.songCount(count))
                    .themeFont(.mono)
                    .foregroundStyle(Theme.fg2)
            }
            Spacer(minLength: 0)
            Text(crowd.title)
                .font(Theme.font(size: 20, weight: .bold))
            Text(crowd.subtitle)
                .font(Theme.font(size: 13))
                .foregroundStyle(Theme.fg2)
                .padding(.top, 2)
        }
        .foregroundStyle(Theme.fg)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 108, maxHeight: 108, alignment: .leading)
        .background(Theme.card2, in: .rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.line, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 15, y: 10)
        .contentShape(.rect(cornerRadius: 26))
        // Read the name first: "Friends, 1 song, Your own crowd".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(crowd.title), \(CrowdSheet.songCount(count)), \(crowd.subtitle)")
    }
}

extension View {
    /// Presents the crowd sheet for a mood, sized to fit its content, in the design's sheet style.
    /// `onPick` runs once the sheet has finished closing, so a screen pushed from it doesn't
    /// slide in underneath the closing sheet.
    func crowdSheet(mood: Binding<Mood?>, songs: [Song], onPick: @escaping (Mood, CrowdFilter) -> Void) -> some View {
        modifier(CrowdSheetPresenter(mood: mood, songs: songs, onPick: onPick))
    }
}

private struct CrowdSheetPresenter: ViewModifier {
    @Binding var mood: Mood?
    var songs: [Song]
    var onPick: (Mood, CrowdFilter) -> Void

    /// The choice made in the sheet, delivered after it closes.
    @State private var pending: (Mood, CrowdFilter)?

    func body(content: Content) -> some View {
        content.sheet(item: $mood, onDismiss: deliverPending) { picked in
            CrowdSheetContainer(mood: picked, songs: songs) { filter in
                pending = (picked, filter)
                mood = nil
            }
        }
    }

    private func deliverPending() {
        guard let (picked, filter) = pending else { return }
        pending = nil
        onPick(picked, filter)
    }
}

/// The crowd sheet, sized to its content.
private struct CrowdSheetContainer: View {
    var mood: Mood
    var songs: [Song]
    var onPick: (CrowdFilter) -> Void

    var body: some View {
        CrowdSheet(mood: mood, songs: songs, onPick: onPick)
            .fittedSheet()
    }
}

#if DEBUG
#Preview("2A · Campfire", traits: .sampleLibrary) {
    @Previewable @Query(sort: \Mood.sortOrder) var moods: [Mood]
    @Previewable @Query var songs: [Song]
    @Previewable @State var picked: Mood?

    Color.clear
        .crowdSheet(mood: $picked, songs: songs) { _, _ in }
        .onAppear { picked = moods.first { $0.name == "Campfire" } }
}
#endif
