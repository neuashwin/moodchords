import SwiftUI
import SwiftData
import UIKit

/// Play mode (design 05): a 3-2-1 count-in, then the sheet scrolls by itself over the
/// song's length. The whole screen is the button: tap to pause, swipe up/down to change
/// speed (saved per song), swipe down from the top (or the small ✕) to exit.
struct PlayScreen: View {
    var song: Song

    @Environment(\.dismiss) private var dismiss
    @AppStorage("playFontSize") private var fontSize: Double = 26

    enum Phase: Equatable { case countIn(Int), playing, paused, finished }

    @State private var phase: Phase = .countIn(3)
    /// Song position. Only the moving parts read it, so the rest of the screen isn't
    /// rebuilt on every frame.
    @State private var clock = PlayClock()
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var speedToast: String?
    @State private var dragStartTime: Double?

    private let parsed: ParsedSong?
    private let duration: Double

    /// Where the lyrics start on screen, and where the "current line" reading point sits.
    private let topInset: CGFloat = 140
    private var readingLine: CGFloat { viewportHeight * 0.32 }

    init(song: Song) {
        self.song = song
        parsed = try? ChordProParser.parse(song.source)
        duration = Double(max(song.durationSeconds, 10))
    }

    /// How far the content has to travel so the last line ends up at the reading point.
    private var travel: CGFloat {
        PlayClock.travel(contentHeight: contentHeight, topInset: topInset, readingLine: readingLine)
    }

    var body: some View {
        let lines = parsed?.lines ?? []

        ZStack(alignment: .top) {
            Theme.stage.ignoresSafeArea()

            ScrollingLyrics(lines: lines, fontSize: fontSize, clock: clock, duration: duration,
                            topInset: topInset, readingLine: readingLine, contentHeight: $contentHeight)
                .accessibilityHidden(phase != .paused && phase != .playing)

            // Fades so lyrics slide in and out softly.
            VStack(spacing: 0) {
                LinearGradient(stops: [.init(color: Theme.stage, location: 0.65), .init(color: Theme.stage.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: topInset + 10)
                Spacer()
                LinearGradient(colors: [Theme.stage.opacity(0), Theme.stage], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            overlay

            // On top of the overlays, so the ✕ and progress stay visible during the count-in too.
            header
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
        .contentShape(.rect)
        .onTapGesture(perform: handleTap)
        .gesture(swipe)
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .task(id: phase) { await run() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .accessibilityAction(named: phase == .playing ? "Pause" : "Play") { handleTap() }
        .accessibilityAction(named: "Faster") { nudgeSpeed(by: 0.1) }
        .accessibilityAction(named: "Slower") { nudgeSpeed(by: -0.1) }
        .accessibilityAction(named: "Exit") { dismiss() }
    }

    // MARK: Header: progress, ✕, status, time left

    private var header: some View {
        VStack(spacing: 8) {
            ProgressLine(clock: clock, duration: duration)
                .frame(height: 4)
                .padding(.horizontal, 28)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.fg2)
                        .frame(width: 30, height: 30)
                        .background(Theme.chip, in: .circle)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exit play mode")

                Spacer()
                SpecLabel(statusLabel)
                    .lineLimit(1)
                    // Swap the words instantly; a crossfade overlapped "Paused" and the title.
                    .transaction { $0.animation = nil }
                Spacer()
                ClockText(clock: clock) { "-" + SongSummary.formatDuration(Int(max(duration - $0, 0).rounded())) }
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.leading, 12)
            .padding(.trailing, 20)
        }
        .padding(.top, 8)
    }

    private var statusLabel: String {
        switch phase {
        case .countIn: song.title
        case .playing: song.scrollSpeed == 1 ? song.title : String(format: "%.1f×", song.scrollSpeed)
        case .paused: "Paused"
        case .finished: "Finished"
        }
    }

    // MARK: Overlays

    @ViewBuilder
    private var overlay: some View {
        switch phase {
        case .countIn(let count):
            countIn(count)
        case .paused:
            pausedOverlay
        case .finished:
            finishedOverlay
        case .playing:
            if let speedToast {
                HStack(spacing: 8) {
                    Image(systemName: speedToast.hasPrefix("Faster") ? "chevron.up.2" : "chevron.down.2")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.chord)
                    Text(speedToast)
                        .font(Theme.font(size: 19, weight: .heavy))
                    Text("· saved for this song")
                        .font(Theme.font(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.fg2)
                    Text(String(format: "%.1f×", song.scrollSpeed))
                        .themeFont(.mono)
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(Theme.chip, in: .capsule)
                }
                .foregroundStyle(Theme.fg)
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .frame(height: 58)
                .background(Theme.sheet, in: .capsule)
                .padding(.top, 110)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func countIn(_ count: Int) -> some View {
        let opening = Array((parsed?.chords ?? []).filter(ChordSheetConverter.isChord).prefix(4))
        return VStack(spacing: 0) {
            SpecLabel("Get ready")
            Text("\(count)")
                .font(Theme.displayFont(size: 220))
                .foregroundStyle(Theme.chord)
                .contentTransition(.numericText(countsDown: true))
                .padding(.top, 6)
            if !opening.isEmpty {
                HStack(spacing: 8) {
                    SpecLabel("Starts on")
                    ForEach(opening, id: \.self) { chord in
                        Text(chord)
                            .font(Theme.font(size: 20, weight: .heavy))
                            .foregroundStyle(Theme.chord)
                            .padding(.horizontal, 12)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Theme.chip, in: .capsule)
                    }
                }
                .padding(.top, 20)
            }
            Text("Tap to skip the count")
                .font(Theme.font(size: 16))
                .foregroundStyle(Theme.fg2)
                .padding(.top, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage)
    }

    private var pausedOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "play.fill")
                .font(.system(size: 50))
                .foregroundStyle(Theme.fg)
                .frame(width: 116, height: 116)
                .background(Theme.chip, in: .circle)
            Text("Paused")
                .font(Theme.font(size: 34, weight: .heavy))
                .foregroundStyle(Theme.fg)
                .padding(.top, 20)
            Text("Tap anywhere to resume · drag to scroll")
                .font(Theme.font(size: 17, weight: .semibold))
                .foregroundStyle(Theme.fg2)
                .padding(.top, 4)
            ClockText(clock: clock) { "\(SongSummary.formatDuration(Int($0))) of \(SongSummary.formatDuration(Int(duration)))" }
                .padding(.top, 12)

            // Text size
            HStack(spacing: 12) {
                textSizeButton("textformat.size.smaller", label: "Smaller text", by: -2)
                Text("Text size")
                    .font(Theme.font(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.fg2)
                textSizeButton("textformat.size.larger", label: "Larger text", by: 2)
            }
            .padding(.top, 26)

            Spacer()
            VStack(spacing: 10) {
                Label("Swipe up or down to change speed", systemImage: "arrow.up.and.down")
                Label("Swipe down from the top to exit", systemImage: "chevron.down.2")
            }
            .font(Theme.font(size: 15, weight: .semibold))
            .foregroundStyle(Theme.fg2)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Nearly opaque, so the lyrics behind don't make the overlay hard to read.
        .background(Theme.stage.opacity(0.97))
    }

    private func textSizeButton(_ symbol: String, label: String, by step: Double) -> some View {
        Button {
            fontSize = min(max(fontSize + step, 18), 40)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .frame(width: 52, height: 52)
                .background(Theme.chip, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var finishedOverlay: some View {
        VStack(spacing: 0) {
            SpecLabel("Song finished")
            Text("That was \(song.title)")
                .font(Theme.font(size: 30, weight: .heavy))
                .foregroundStyle(Theme.fg)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            VStack(spacing: 10) {
                AccentCapsuleButton(title: "Play again", symbol: "arrow.counterclockwise") { restart() }
                GlassCapsuleButton(title: "Done", symbol: "checkmark", note: nil) { dismiss() }
            }
            .padding(.top, 30)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage.opacity(0.9))
    }

    // MARK: Behaviour

    /// Drives the count-in and the scroll. Restarts whenever the phase changes.
    private func run() async {
        switch phase {
        case .countIn(let count):
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation { phase = count > 1 ? .countIn(count - 1) : .playing }
        case .playing:
            var last = Date.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let now = Date.now
                clock.songTime += now.timeIntervalSince(last) * song.scrollSpeed
                last = now
                if clock.songTime >= duration {
                    clock.songTime = duration
                    withAnimation { phase = .finished }
                    return
                }
            }
        case .paused, .finished:
            break
        }
    }

    private func handleTap() {
        switch phase {
        case .countIn: withAnimation { phase = .playing }
        case .playing: withAnimation { phase = .paused }
        case .paused: withAnimation { phase = .playing }
        case .finished: break
        }
    }

    private func restart() {
        clock.songTime = 0
        withAnimation { phase = .countIn(3) }
    }

    /// Swipes: speed while playing, scroll while paused, exit when starting at the top.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard phase == .paused, travel > 0 else { return }
                if dragStartTime == nil { dragStartTime = clock.songTime }
                let delta = -Double(value.translation.height / travel) * duration
                clock.songTime = min(max((dragStartTime ?? 0) + delta, 0), duration)
            }
            .onEnded { value in
                defer { dragStartTime = nil }
                let dy = value.translation.height
                if value.startLocation.y < 110, dy > 80 {
                    dismiss()
                    return
                }
                guard phase == .playing, abs(dy) > 40, abs(dy) > abs(value.translation.width) else { return }
                nudgeSpeed(by: dy < 0 ? 0.1 : -0.1)
            }
    }

    private func nudgeSpeed(by step: Double) {
        let newSpeed = ((song.scrollSpeed + step) * 10).rounded() / 10
        song.scrollSpeed = min(max(newSpeed, 0.5), 2.0)
        withAnimation { speedToast = step > 0 ? "Faster" : "Slower" }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { speedToast = nil }
        }
    }
}

// MARK: - Clock and moving parts

/// How far into the song Play mode is, in seconds of song time.
@Observable
final class PlayClock {
    var songTime: Double = 0

    /// How far the lyrics travel so the last line ends at the reading point.
    static func travel(contentHeight: CGFloat, topInset: CGFloat, readingLine: CGFloat) -> CGFloat {
        max(contentHeight + topInset - readingLine - 60, 0)
    }
}

/// The lyrics, moved up as the song plays, with the current line highlighted.
private struct ScrollingLyrics: View {
    let lines: [SongLine]
    let fontSize: Double
    let clock: PlayClock
    let duration: Double
    let topInset: CGFloat
    let readingLine: CGFloat
    @Binding var contentHeight: CGFloat

    /// Top of each line in the content, by line index.
    @State private var lineTops: [Int: CGFloat] = [:]

    var body: some View {
        let travel = PlayClock.travel(contentHeight: contentHeight, topInset: topInset, readingLine: readingLine)
        let offset = travel * CGFloat(min(clock.songTime / duration, 1))
        let reading = offset + readingLine - topInset
        let current = lineTops.filter { $0.value <= reading + 4 }.max { $0.value < $1.value }?.key

        // The lyrics hang in an overlay on a screen-sized clear view: an overlay never changes
        // its parent's size, so a long song can't push the header and overlays off-screen.
        Color.clear
            .overlay(alignment: .top) {
                PlayLines(lines: lines, fontSize: fontSize, currentLine: current)
                    .equatable()
                    .padding(.horizontal, 26)
                    // Always its full height, so the scroll distance is right.
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                    .onPreferenceChange(LineTopsKey.self) { lineTops = $0 }
                    .offset(y: topInset - offset)
            }
            .clipped()
    }
}

/// The thin progress bar at the top.
private struct ProgressLine: View {
    let clock: PlayClock
    let duration: Double

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Theme.chip)
                .overlay(alignment: .leading) {
                    Capsule().fill(Theme.chord)
                        .frame(width: proxy.size.width * CGFloat(min(clock.songTime / duration, 1)))
                }
        }
        .accessibilityHidden(true)
    }
}

/// A mono label showing something worked out from the song position (time left, "0:19 of 2:45").
private struct ClockText: View {
    let clock: PlayClock
    let text: (Double) -> String

    var body: some View {
        Text(text(clock.songTime))
            .themeFont(.mono)
            .foregroundStyle(Theme.fg2)
    }
}

// MARK: - The lines

/// Reports where each line sits, so Play mode knows which one is current.
private struct LineTopsKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The song's lines in stage style. Equatable so it isn't rebuilt on every scroll frame.
private struct PlayLines: View, Equatable {
    let lines: [SongLine]
    let fontSize: Double
    let currentLine: Int?

    var body: some View {
        let size = CGFloat(fontSize)
        VStack(alignment: .leading, spacing: size * 0.4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Group {
                    switch line {
                    case .blank:
                        Color.clear.frame(height: size * 0.3)
                    case .section(let name):
                        SectionHeading(name: name, fontSize: size * 0.7, color: Theme.fg3)
                    case .note:
                        EmptyView()
                    case .lyrics(let segments):
                        lyric(segments, index: index, size: size)
                    }
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: LineTopsKey.self,
                                               value: [index: proxy.frame(in: .named("playContent")).minY])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coordinateSpace(.named("playContent"))
    }

    private func lyric(_ segments: [ChordSegment], index: Int, size: CGFloat) -> some View {
        let isCurrent = index == currentLine
        let isPast = currentLine.map { index < $0 } ?? false
        return ChordLineView(segments: segments, fontSize: size,
                             textColor: isPast ? Theme.fg3 : Theme.fg,
                             chordColor: isPast ? Theme.fg3 : Theme.chord)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isCurrent ? Theme.chip : .clear, in: .rect(cornerRadius: 22))
            .padding(.horizontal, -14)
            .animation(.easeInOut(duration: 0.3), value: isCurrent)
    }
}
