import Foundation

/// The parameters for a synthesized sound. Every built-in sound and every sound
/// made in the designer is one of these, so the app ships no audio files and every
/// sound it makes is free to use.
struct SynthRecipe: Codable, Equatable {

    enum Waveform: String, Codable, CaseIterable {
        case sine, square, sawtooth, triangle, noise

        var displayName: String {
            switch self {
            case .sine: return "Sine"
            case .square: return "Square"
            case .sawtooth: return "Saw"
            case .triangle: return "Triangle"
            case .noise: return "Noise"
            }
        }
    }

    var waveform: Waveform
    /// Pitch at the start of the sound, in Hz.
    var startFrequency: Double
    /// Pitch at the end of the sound, in Hz. The pitch glides between the two.
    var endFrequency: Double
    /// Length in seconds.
    var duration: Double
    /// How fast the pitch wobbles, in Hz. 0 turns vibrato off.
    var vibratoRate: Double = 0
    /// How far the pitch wobbles, as a fraction of the pitch (0...0.5).
    var vibratoDepth: Double = 0
    /// How fast the sound chops on and off, in Hz. 0 turns pulsing off.
    var pulseRate: Double = 0
    /// 0 holds the volume steady; 1 fades out quickly.
    var decay: Double = 0
    /// 0 is clean; 1 adds a detuned second voice and distortion.
    var grit: Double = 0

    static let frequencyRange: ClosedRange<Double> = 40...4000
    static let durationRange: ClosedRange<Double> = 0.1...3

    static func random() -> SynthRecipe {
        func randomFrequency() -> Double {
            let range = frequencyRange
            return range.lowerBound * pow(range.upperBound / range.lowerBound, Double.random(in: 0.1...0.85))
        }
        return SynthRecipe(
            waveform: Waveform.allCases.randomElement()!,
            startFrequency: randomFrequency(),
            endFrequency: randomFrequency(),
            duration: Double.random(in: 0.2...1.4),
            vibratoRate: Bool.random() ? Double.random(in: 2...30) : 0,
            vibratoDepth: Double.random(in: 0...0.25),
            pulseRate: Int.random(in: 0..<3) == 0 ? Double.random(in: 3...15) : 0,
            decay: Double.random(in: 0...0.8),
            grit: Bool.random() ? Double.random(in: 0...0.8) : 0
        )
    }
}
