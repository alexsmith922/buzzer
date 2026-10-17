import AVFoundation

/// Plays sound effects with as little delay as possible by keeping a ready player per sound.
final class SoundPlayer {

    static let shared = SoundPlayer()

    private struct CachedPlayer {
        let source: SoundEffect.Source
        let player: AVAudioPlayer
    }

    private var cache: [UUID: CachedPlayer] = [:]
    private var previewPlayer: AVAudioPlayer?

    /// Plays even when the ringer switch is on silent, as a buzzer should.
    func activatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    func activateRecordingSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    /// Builds the player ahead of time so the first press is instant.
    func prepare(_ sound: SoundEffect) {
        _ = cachedPlayer(for: sound)
    }

    /// Plays from the start, restarting the sound if it is already playing.
    func play(_ sound: SoundEffect) {
        guard let player = cachedPlayer(for: sound) else { return }
        player.currentTime = 0
        player.play()
    }

    func preview(_ recipe: SynthRecipe) {
        play(previewPlayer: try? AVAudioPlayer(data: SoundSynthesizer.wavData(for: recipe),
                                               fileTypeHint: AVFileType.wav.rawValue))
    }

    func preview(contentsOf url: URL) {
        play(previewPlayer: try? AVAudioPlayer(contentsOf: url))
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    private func play(previewPlayer player: AVAudioPlayer?) {
        previewPlayer?.stop()
        previewPlayer = player
        player?.play()
    }

    private func cachedPlayer(for sound: SoundEffect) -> AVAudioPlayer? {
        // A sound edited in the designer keeps its ID, so compare the source too.
        if let cached = cache[sound.id], cached.source == sound.source {
            return cached.player
        }

        let newPlayer: AVAudioPlayer?
        switch sound.source {
        case .synth(let recipe):
            newPlayer = try? AVAudioPlayer(data: SoundSynthesizer.wavData(for: recipe),
                                           fileTypeHint: AVFileType.wav.rawValue)
        case .recording(let fileName):
            newPlayer = try? AVAudioPlayer(contentsOf: SoundLibrary.shared.recordingURL(for: fileName))
        }

        guard let player = newPlayer else {
            cache[sound.id] = nil
            return nil
        }
        player.prepareToPlay()
        cache[sound.id] = CachedPlayer(source: sound.source, player: player)
        return player
    }
}
