//
//  PitchDetector.swift
//  Moodchords
//
//  Finds the pitch of a plucked string in a short burst of audio, using the YIN method
//  (de Cheveigné & Kawahara, 2002): look for the delay at which the signal best repeats.
//

import Accelerate
import Foundation

nonisolated struct PitchDetector: Sendable {
    var sampleRate: Double
    /// Lowest/highest pitch looked for. A guitar's open strings run 82–330 Hz; the range
    /// leaves room for detuned strings and the first harmonics.
    var minimumFrequency: Double = 60
    var maximumFrequency: Double = 1000
    /// YIN's confidence threshold: lower = stricter.
    var threshold: Float = 0.15
    /// Quieter than this (RMS) counts as silence.
    var silenceLevel: Float = 0.006

    /// The pitch in Hz, or nil for silence or noise.
    func pitch(of samples: [Float]) -> Double? {
        let maxLag = Int(sampleRate / minimumFrequency)
        let minLag = max(Int(sampleRate / maximumFrequency), 2)
        let window = samples.count - maxLag
        guard window > maxLag / 2, minLag < maxLag else { return nil }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        guard rms > silenceLevel else { return nil }

        // Difference function: how different the signal is from itself delayed by `lag`.
        var difference = [Float](repeating: 0, count: maxLag + 1)
        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            for lag in 1...maxLag {
                var distance: Float = 0
                vDSP_distancesq(base, 1, base + lag, 1, &distance, vDSP_Length(window))
                difference[lag] = distance
            }
        }

        // Cumulative mean normalised difference, then the first dip below the threshold.
        var normalised = [Float](repeating: 1, count: maxLag + 1)
        var runningSum: Float = 0
        for lag in 1...maxLag {
            runningSum += difference[lag]
            normalised[lag] = runningSum > 0 ? difference[lag] * Float(lag) / runningSum : 1
        }

        var lag = minLag
        var found: Int?
        while lag < maxLag {
            if normalised[lag] < threshold {
                // Walk down to the bottom of this dip.
                while lag + 1 < maxLag, normalised[lag + 1] < normalised[lag] { lag += 1 }
                found = lag
                break
            }
            lag += 1
        }
        guard let best = found else { return nil }

        // Parabolic interpolation between neighbouring lags for sub-sample accuracy.
        let refined: Double
        if best > 1, best < maxLag {
            let a = Double(normalised[best - 1]), b = Double(normalised[best]), c = Double(normalised[best + 1])
            let denominator = a - 2 * b + c
            refined = denominator != 0 ? Double(best) + 0.5 * (a - c) / denominator : Double(best)
        } else {
            refined = Double(best)
        }
        return sampleRate / refined
    }
}

/// Notes, strings and cents for the tuner.
nonisolated enum Tuning {
    struct GuitarString: Equatable, Sendable, Identifiable {
        /// 6 = low E … 1 = high e.
        var number: Int
        var note: String
        var frequency: Double
        var id: Int { number }

        var ordinalName: String {
            switch number {
            case 1: "1st"
            case 2: "2nd"
            case 3: "3rd"
            default: "\(number)th"
            }
        }
    }

    /// Standard tuning, low to high, at A4 = 440 Hz.
    static let standard: [GuitarString] = [
        .init(number: 6, note: "E", frequency: 82.41),
        .init(number: 5, note: "A", frequency: 110.00),
        .init(number: 4, note: "D", frequency: 146.83),
        .init(number: 3, note: "G", frequency: 196.00),
        .init(number: 2, note: "B", frequency: 246.94),
        .init(number: 1, note: "E", frequency: 329.63),
    ]

    /// How far `frequency` is from `target`, in cents (100 cents = one semitone).
    static func cents(_ frequency: Double, from target: Double) -> Double {
        1200 * log2(frequency / target)
    }

    /// The open string closest to the pitch.
    static func nearestString(to frequency: Double) -> GuitarString {
        standard.min { abs(cents(frequency, from: $0.frequency)) < abs(cents(frequency, from: $1.frequency)) }!
    }

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// The nearest note name to any frequency ("A", "C#").
    static func noteName(for frequency: Double) -> String {
        let midi = Int((69 + 12 * log2(frequency / 440)).rounded())
        return noteNames[((midi % 12) + 12) % 12]
    }

    /// Within this many cents counts as in tune.
    static let inTuneCents: Double = 5
}
