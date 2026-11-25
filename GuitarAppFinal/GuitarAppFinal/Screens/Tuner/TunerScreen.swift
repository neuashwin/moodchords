import SwiftUI
import UIKit

/// The guitar tuner (design 06). Auto-detects the nearest string; tap a string to lock it.
/// State is shown by needle position, label and icon, never colour alone.
struct TunerScreen: View {
    @State private var tuner = TunerEngine()
    @State private var lockedString: Tuning.GuitarString?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.stage.ignoresSafeArea()
            switch tuner.permission {
            case .granted: tunerView
            case .unknown: permissionView
            case .denied: deniedView
            }
        }
        .onAppear { tuner.start() }
        .onDisappear { tuner.stop() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { tuner.start() } else { tuner.stop() }
        }
    }

    // MARK: Reading

    private enum Status {
        case listening, flat, sharp, inTune

        var label: String {
            switch self {
            case .listening: "Pluck a string"
            case .flat: "Tune up"
            case .sharp: "Tune down"
            case .inTune: "In tune"
            }
        }

        var symbol: String {
            switch self {
            case .listening: "ear"
            case .flat: "arrow.up"
            case .sharp: "arrow.down"
            case .inTune: "checkmark.circle.fill"
            }
        }
    }

    private struct Reading {
        var target: Tuning.GuitarString?
        var cents: Double?
        var status: Status
    }

    private var reading: Reading {
        guard let frequency = tuner.frequency else {
            return Reading(target: lockedString, cents: nil, status: .listening)
        }
        let target = lockedString ?? Tuning.nearestString(to: frequency)
        let cents = Tuning.cents(frequency, from: target.frequency)
        let status: Status = abs(cents) <= Tuning.inTuneCents ? .inTune : cents < 0 ? .flat : .sharp
        return Reading(target: target, cents: cents, status: status)
    }

    // MARK: Tuner

    private var tunerView: some View {
        let reading = reading
        let pillColor: Color = switch reading.status {
        case .listening: Theme.chip
        case .inTune: Theme.ok
        case .flat, .sharp: Theme.chord
        }

        return VStack(spacing: 0) {
            HStack {
                Text("Tuner")
                    .font(Theme.font(.headline))
                    .foregroundStyle(Theme.fg)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("A4 · 440")
                    .themeFont(.mono)
                    .foregroundStyle(Theme.fg)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Theme.chip, in: .capsule)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            SpecLabel("Standard · E A D G B E")
                .padding(.top, 26)

            Text(reading.target?.note ?? "–")
                .font(Theme.displayFont(size: 200))
                .foregroundStyle(reading.status == .inTune ? Theme.ok : reading.cents == nil ? Theme.fg3 : Theme.fg)
                .frame(height: 180)
                .contentTransition(.numericText())
                .padding(.top, 10)

            Text(reading.target.map { "\($0.ordinalName) string · \($0.note)" } ?? "Listening…")
                .font(Theme.font(size: 22, weight: .bold))
                .foregroundStyle(Theme.fg)
                .padding(.top, 8)
            Text(hzLine(reading))
                .themeFont(.mono)
                .foregroundStyle(Theme.fg2)
                .padding(.top, 6)

            meter(cents: reading.cents)
                .padding(.horizontal, 24)
                .padding(.top, 28)

            Label(reading.status.label, systemImage: reading.status.symbol)
                .font(Theme.font(size: 22, weight: .heavy))
                .foregroundStyle(reading.status == .listening ? Theme.fg : Theme.stage)
                .padding(.leading, 18)
                .padding(.trailing, 24)
                .frame(height: 56)
                .background(pillColor, in: .capsule)
                .padding(.top, 16)
                .animation(.easeInOut(duration: 0.2), value: reading.status.label)

            Spacer(minLength: 12)

            if tuner.failedToStart {
                VStack(spacing: 6) {
                    Text("Couldn't start the microphone. Close other apps that use it, then try again.")
                        .font(Theme.font(size: 14))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                    Button("Try again") { tuner.start() }
                        .font(Theme.font(size: 15, weight: .bold))
                        .foregroundStyle(Theme.chord)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            }

            Text(lockedString == nil ? "Auto-detect · tap a string to lock it" : "Locked · tap it again for auto-detect")
                .font(Theme.font(size: 14))
                .foregroundStyle(Theme.fg2)
            strings(active: reading.target)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
        .accessibilityElement(children: .contain)
    }

    private func hzLine(_ reading: Reading) -> String {
        guard let frequency = tuner.frequency, let target = reading.target else { return "Pluck any open string" }
        return String(format: "%.1f Hz · target %.1f", frequency, target.frequency)
    }

    /// Ticks from -50 to +50 cents, a green "in tune" zone, and the needle.
    private func meter(cents: Double?) -> some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.okBackground)
                        .frame(width: 40, height: 70)
                        .position(x: width / 2, y: 39)
                    HStack(spacing: 0) {
                        ForEach(0..<21, id: \.self) { tick in
                            let fromCentre = tick - 10
                            Capsule()
                                .fill(fromCentre == 0 ? Theme.fg : Theme.fg3)
                                .frame(width: 2, height: fromCentre == 0 ? 60 : fromCentre % 5 == 0 ? 40 : 22)
                            if tick < 20 { Spacer(minLength: 0) }
                        }
                    }
                    .frame(height: 78)
                    if let cents {
                        let clamped = min(max(cents, -50), 50)
                        Capsule()
                            .fill(abs(cents) <= Tuning.inTuneCents ? Theme.ok : Theme.chord)
                            .frame(width: 8, height: 90)
                            .position(x: width / 2 + CGFloat(clamped / 50) * (width / 2 - 4), y: 39)
                            .animation(.spring(duration: 0.4), value: clamped)
                    }
                }
            }
            .frame(height: 80)

            HStack {
                Text("♭ FLAT")
                Spacer()
                Text(cents.map { String(format: "%+.0f¢", $0) } ?? "")
                    .foregroundStyle(Theme.fg)
                Spacer()
                Text("SHARP ♯")
            }
            .themeFont(.mono)
            .foregroundStyle(Theme.fg2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cents.map { abs($0) <= Tuning.inTuneCents ? "In tune" : String(format: "%.0f cents %@", abs($0), $0 < 0 ? "flat" : "sharp") } ?? "No note")
    }

    private func strings(active: Tuning.GuitarString?) -> some View {
        HStack(spacing: 0) {
            ForEach(Tuning.standard) { string in
                let isActive = string == active
                Button {
                    lockedString = lockedString == string ? nil : string
                } label: {
                    VStack(spacing: 7) {
                        Text(string.note)
                            .font(Theme.font(size: 22, weight: .heavy))
                            .foregroundStyle(isActive ? Theme.stage : Theme.fg)
                            .frame(width: 52, height: 52)
                            .background(isActive ? (reading.status == .inTune ? Theme.ok : Theme.chord) : Theme.chip, in: .circle)
                            .overlay {
                                if lockedString == string {
                                    Circle().strokeBorder(Theme.fg, lineWidth: 2).padding(-4)
                                }
                            }
                        Text("\(string.number)")
                            .themeFont(.mono)
                            .foregroundStyle(Theme.fg2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(string.ordinalName) string, \(string.note)")
                .accessibilityAddTraits(lockedString == string ? .isSelected : [])
                .accessibilityHint(lockedString == string ? "Tap to go back to auto-detect" : "Tap to lock the tuner to this string")
            }
        }
    }

    // MARK: Permission

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "mic.fill")
                .font(.system(size: 54))
                .foregroundStyle(.white)
                .frame(width: 128, height: 128)
                .background(Theme.accentGradient, in: .circle)
                .padding(.top, 70)
                .accessibilityHidden(true)
            Text("Let the tuner hear your guitar")
                .font(Theme.font(size: 34, weight: .heavy))
                .foregroundStyle(Theme.fg)
                .padding(.top, 30)
            Text("Moodchords uses the microphone only while the tuner is open, to hear which note you're playing.")
                .font(Theme.font(size: 18))
                .foregroundStyle(Theme.fg2)
                .padding(.top, 14)
            Label("Sound stays on your phone. Nothing is recorded or sent.", systemImage: "lock.fill")
                .font(Theme.font(size: 16, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .padding(.top, 20)
            Spacer()
            Button {
                Task { await tuner.requestPermission() }
            } label: {
                Text("Allow microphone")
                    .font(Theme.font(size: 19, weight: .heavy))
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(Theme.fg, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 28)
    }

    private var deniedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.fg2)
                .accessibilityHidden(true)
            Text("The microphone is off")
                .font(Theme.font(size: 26, weight: .heavy))
                .foregroundStyle(Theme.fg)
            Text("To use the tuner, allow Moodchords to use the microphone in Settings.")
                .font(Theme.font(size: 16))
                .foregroundStyle(Theme.fg2)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(Theme.font(.bodyStrong))
            .foregroundStyle(Theme.chord)
            .padding(.top, 6)
        }
        .padding(32)
    }
}
