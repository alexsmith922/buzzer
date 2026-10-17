import Foundation

/// A sound the buzzer can play: synthesized from a recipe, a sound effect file the app
/// downloads, or recorded with the mic.
struct SoundEffect: Codable, Equatable, Identifiable {

    enum Source: Codable, Equatable {
        case synth(SynthRecipe)
        /// File name of a recording inside the sound library's directory.
        case recording(fileName: String)
        /// File name of a sound effect the app downloads once and keeps on device.
        case downloaded(fileName: String)
    }

    let id: UUID
    var name: String
    var source: Source
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, source: Source, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.source = source
        self.isBuiltIn = isBuiltIn
    }

    var recipe: SynthRecipe? {
        if case .synth(let recipe) = source { return recipe }
        return nil
    }

    var subtitle: String {
        switch source {
        case .synth(let recipe): return "Synth · \(recipe.waveform.displayName)"
        case .recording: return "Recording"
        case .downloaded: return "Sound Effect"
        }
    }
}

// MARK: - Built-in sounds

extension SoundEffect {

    private static func classic(_ id: String, _ name: String, _ fileName: String) -> SoundEffect {
        SoundEffect(id: UUID(uuidString: id)!, name: name, source: .downloaded(fileName: fileName), isBuiltIn: true)
    }

    /// Recorded game show sound effects, hosted in the repo's Sounds folder. The app
    /// downloads each one the first time it can and shows it once it's on the device.
    static let classics: [SoundEffect] = [
        classic("6B1E1E3A-0002-4000-8000-000000000001", "Correct Answer", "correct.mp3"),
        classic("6B1E1E3A-0002-4000-8000-000000000002", "Wrong Answer Buzzer", "wrong.mp3"),
        classic("6B1E1E3A-0002-4000-8000-000000000003", "Time's Up", "times-up.mp3"),
        classic("6B1E1E3A-0002-4000-8000-000000000004", "Drumroll", "drumroll.mp3"),
        classic("6B1E1E3A-0002-4000-8000-000000000005", "Applause", "applause.mp3"),
        classic("6B1E1E3A-0002-4000-8000-000000000006", "Aww", "aww.mp3"),
        classic("6B1E1E3A-0002-4000-8000-000000000007", "Rimshot", "rimshot.mp3"),
        classic("6B1E1E3A-0002-4000-8000-000000000008", "Sad Trombone", "sad-trombone.mp3"),
    ]

    private static func builtIn(_ id: String, _ name: String, _ recipe: SynthRecipe) -> SoundEffect {
        SoundEffect(id: UUID(uuidString: id)!, name: name, source: .synth(recipe), isBuiltIn: true)
    }

    /// Stable IDs keep the user's selection across launches.
    static let builtIns: [SoundEffect] = [
        builtIn("6B1E1E3A-0001-4000-8000-000000000001", "Game Show Buzzer",
                SynthRecipe(waveform: .square, startFrequency: 120, endFrequency: 112, duration: 0.9,
                            decay: 0.1, grit: 0.55)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000002", "Wrong Answer",
                SynthRecipe(waveform: .sawtooth, startFrequency: 330, endFrequency: 196, duration: 1.5,
                            vibratoRate: 6, vibratoDepth: 0.03, pulseRate: 2, decay: 0.3, grit: 0.2)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000003", "Correct Ding",
                SynthRecipe(waveform: .sine, startFrequency: 1568, endFrequency: 1568, duration: 1.2,
                            decay: 1)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000004", "Air Horn",
                SynthRecipe(waveform: .sawtooth, startFrequency: 415, endFrequency: 400, duration: 1.2,
                            decay: 0.05, grit: 0.8)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000005", "Laser",
                SynthRecipe(waveform: .square, startFrequency: 2000, endFrequency: 150, duration: 0.35,
                            decay: 0.4)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000006", "Alarm",
                SynthRecipe(waveform: .square, startFrequency: 880, endFrequency: 880, duration: 1.2,
                            pulseRate: 8)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000007", "Siren",
                SynthRecipe(waveform: .sine, startFrequency: 700, endFrequency: 700, duration: 2,
                            vibratoRate: 1.2, vibratoDepth: 0.3, grit: 0.1)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000008", "Boing",
                SynthRecipe(waveform: .triangle, startFrequency: 120, endFrequency: 480, duration: 0.6,
                            vibratoRate: 18, vibratoDepth: 0.15, decay: 0.6)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000009", "Ref Whistle",
                SynthRecipe(waveform: .sine, startFrequency: 2800, endFrequency: 2800, duration: 0.9,
                            vibratoRate: 40, vibratoDepth: 0.04, grit: 0.1)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000010", "Static Zap",
                SynthRecipe(waveform: .noise, startFrequency: 3000, endFrequency: 800, duration: 0.4,
                            decay: 0.5)),
        builtIn("6B1E1E3A-0001-4000-8000-000000000011", "Power Up",
                SynthRecipe(waveform: .square, startFrequency: 200, endFrequency: 1600, duration: 0.6,
                            vibratoRate: 30, vibratoDepth: 0.1, decay: 0.2)),
    ]
}
