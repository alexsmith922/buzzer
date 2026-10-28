import AppIntents

extension PlayLastSoundIntent {

    @MainActor
    func perform() async throws -> some IntentResult {
        // When the app was launched in the background just for this, the session has to
        // be ready before the sound starts or it won't be heard.
        await SoundPlayer.shared.activatePlaybackSession()
        SoundPlayer.shared.play(BuzzerBoard.shared.lastUsedSound)
        return .result()
    }
}
