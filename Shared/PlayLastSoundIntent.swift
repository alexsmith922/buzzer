import AppIntents

/// Plays the last buzzer sound without opening the app. Because it's an audio playback
/// intent, the system runs it in the app's process, launching the app in the background
/// if needed, so the app's own player makes the sound. Each target supplies `perform()`.
struct PlayLastSoundIntent: AudioPlaybackIntent {

    static let title: LocalizedStringResource = "Play Last Buzzer Sound"
    static let description = IntentDescription("Plays the sound of the buzzer you used last.")

    init() {}
}
