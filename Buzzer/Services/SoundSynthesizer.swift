import Foundation

/// Renders a `SynthRecipe` into 16-bit mono WAV audio.
enum SoundSynthesizer {

    static let sampleRate = 44_100.0

    static func wavData(for recipe: SynthRecipe) -> Data {
        let samples = samples(for: recipe)
        let bytesPerSample = 2
        let dataSize = UInt32(samples.count * bytesPerSample)

        var data = Data(capacity: 44 + Int(dataSize))
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func appendTag(_ tag: String) {
            data.append(contentsOf: Array(tag.utf8))
        }

        appendTag("RIFF")
        append(UInt32(36) + dataSize)
        appendTag("WAVE")
        appendTag("fmt ")
        append(UInt32(16))                                        // fmt chunk size
        append(UInt16(1))                                         // PCM
        append(UInt16(1))                                         // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate) * UInt32(bytesPerSample))       // byte rate
        append(UInt16(bytesPerSample))                            // block align
        append(UInt16(16))                                        // bits per sample
        appendTag("data")
        append(dataSize)
        for sample in samples {
            append(Int16(max(-1, min(1, sample)) * Float(Int16.max)))
        }
        return data
    }

    static func samples(for recipe: SynthRecipe) -> [Float] {
        let duration = min(max(recipe.duration, 0.05), 5)
        let count = Int(duration * sampleRate)
        let startFrequency = max(recipe.startFrequency, 20)
        let endFrequency = max(recipe.endFrequency, 20)
        let grit = min(max(recipe.grit, 0), 1)
        let attack = 0.005
        let release = min(0.04, duration * 0.2)

        var output = [Float](repeating: 0, count: count)
        var phase = 0.0
        var detunedPhase = 0.0
        var noise = NoiseOscillator()
        var detunedNoise = NoiseOscillator()
        var peak: Float = 0

        for i in 0..<count {
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Exponential glide sounds even to the ear, unlike a linear one.
            var frequency = startFrequency * pow(endFrequency / startFrequency, progress)
            if recipe.vibratoRate > 0 && recipe.vibratoDepth > 0 {
                frequency *= 1 + recipe.vibratoDepth * sin(2 * .pi * recipe.vibratoRate * t)
            }

            let step = frequency / sampleRate
            let detunedStep = step * (1 + 0.025 * grit)
            phase = (phase + step).truncatingRemainder(dividingBy: 1)
            detunedPhase = (detunedPhase + detunedStep).truncatingRemainder(dividingBy: 1)

            var value: Double
            if recipe.waveform == .noise {
                value = noise.next(step: step * 4) + grit * detunedNoise.next(step: detunedStep * 4)
            } else {
                value = oscillator(recipe.waveform, phase) + grit * oscillator(recipe.waveform, detunedPhase)
            }
            value /= 1 + grit
            if grit > 0 {
                value = tanh(value * (1 + grit * 4))
            }

            var amplitude = 1.0
            if t < attack {
                amplitude = t / attack
            }
            let remaining = duration - t
            if remaining < release {
                amplitude *= remaining / release
            }
            amplitude *= exp(-recipe.decay * 6 * progress)
            if recipe.pulseRate > 0 {
                // A steep sine reads as on/off without the clicks of a hard gate.
                let gate = 0.5 + 2 * sin(2 * .pi * recipe.pulseRate * t)
                amplitude *= min(max(gate, 0), 1)
            }

            let sample = Float(value * amplitude)
            output[i] = sample
            peak = max(peak, abs(sample))
        }

        // Normalize so every sound plays at a similar, loud level.
        if peak > 0 {
            let gain = 0.85 / peak
            for i in 0..<count {
                output[i] *= gain
            }
        }
        return output
    }

    /// One cycle of `waveform` at `phase` in 0..<1, ranging -1...1.
    private static func oscillator(_ waveform: SynthRecipe.Waveform, _ phase: Double) -> Double {
        switch waveform {
        case .sine: return sin(2 * .pi * phase)
        case .square: return phase < 0.5 ? 1 : -1
        case .sawtooth: return 2 * phase - 1
        case .triangle: return 4 * abs(phase - 0.5) - 1
        case .noise: return Double.random(in: -1...1)
        }
    }

    /// Sample-and-hold noise, so the pitch sliders still shape how noise sounds.
    private struct NoiseOscillator {
        private var phase = 0.0
        private var value = 0.0

        mutating func next(step: Double) -> Double {
            phase += step
            if phase >= 1 {
                phase = phase.truncatingRemainder(dividingBy: 1)
                value = Double.random(in: -1...1)
            }
            return value
        }
    }
}
