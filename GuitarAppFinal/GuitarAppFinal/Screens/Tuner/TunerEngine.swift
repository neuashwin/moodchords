import AVFoundation
import Foundation

/// Listens to the microphone and publishes the detected pitch. The mic is only on while
/// the tuner is showing (`start()` / `stop()`); nothing is recorded or stored.
@Observable
final class TunerEngine {
    enum Permission { case unknown, granted, denied }

    private(set) var permission: Permission
    /// Smoothed pitch in Hz, or nil when nothing is being played.
    private(set) var frequency: Double?
    /// True when the microphone couldn't be started (e.g. another app is using it).
    private(set) var failedToStart = false

    private let capture = AudioCapture()
    private var wantsToRun = false
    private var recent: [Double] = []
    private var lastHeard = Date.distantPast

    init() {
        permission = switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        default: .unknown
        }
    }

    func requestPermission() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        permission = granted ? .granted : .denied
        if granted { start() }
    }

    func start() {
        guard permission == .granted, !wantsToRun else { return }
        wantsToRun = true
        failedToStart = false
        capture.start { [weak self] pitch in
            Task { @MainActor in self?.receive(pitch) }
        } completion: { [weak self] started in
            Task { @MainActor in
                guard let self else { return }
                self.failedToStart = !started
                if !started { self.wantsToRun = false }
            }
        }
    }

    func stop() {
        guard wantsToRun else { return }
        wantsToRun = false
        capture.stop()
        frequency = nil
        recent.removeAll()
    }

    /// Keeps the median of the last few readings, so the needle doesn't jitter,
    /// and holds the last note briefly after the string fades.
    private func receive(_ pitch: Double?) {
        guard wantsToRun else { return }
        if let pitch {
            recent.append(pitch)
            if recent.count > 5 { recent.removeFirst() }
            frequency = recent.sorted()[recent.count / 2]
            lastHeard = .now
        } else if Date.now.timeIntervalSince(lastHeard) > 1.2 {
            frequency = nil
            recent.removeAll()
        }
    }
}

/// Owns the audio engine. Everything runs on its own serial queue: setting up the audio
/// session and engine can block for a moment, and doing that on the main thread made the
/// app hang (and get killed) right after the microphone permission was granted.
nonisolated final class AudioCapture: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.ashwin.Moodchords.tuner-audio")
    private let engine = AVAudioEngine()
    private var running = false

    func start(onPitch: @escaping @Sendable (Double?) -> Void, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            guard !running else { completion(true); return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement)
                try session.setActive(true)

                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else { completion(false); return }
                let detector = PitchDetector(sampleRate: format.sampleRate)
                input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
                    guard let channel = buffer.floatChannelData?[0] else { return }
                    let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                    onPitch(detector.pitch(of: samples))
                }
                try engine.start()
                running = true
                completion(true)
            } catch {
                engine.inputNode.removeTap(onBus: 0)
                try? AVAudioSession.sharedInstance().setActive(false)
                completion(false)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            guard running else { return }
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            running = false
        }
    }
}
