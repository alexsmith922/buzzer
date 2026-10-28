import AppIntents

extension PlayLastSoundIntent {

    /// The system runs audio playback intents in the app, not here. The widget only needs
    /// the intent to build its button.
    func perform() async throws -> some IntentResult {
        .result()
    }
}
