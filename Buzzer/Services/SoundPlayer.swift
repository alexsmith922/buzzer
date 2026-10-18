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

    /// Activating the audio session can block, so it happens off the main thread.
    /// A serial queue keeps playback and recording switches in the order requested.
    private let sessionQueue = DispatchQueue(label: "Buzzer.AudioSession", qos: .userInitiated)

    /// Plays even when the ringer switch is on silent, as a buzzer should.
    func activatePlaybackSession() {
        sessionQueue.async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
        }
    }

    /// Calls `completion` on the main thread with nil once the session is ready, or the error.
    func activateRecordingSession(completion: @escaping (Error?) -> Void) {
        sessionQueue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
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
        case .downloaded(let fileName):
            newPlayer = SoundDownloader.shared.localURL(for: fileName).flatMap { try? AVAudioPlayer(contentsOf: $0) }
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
